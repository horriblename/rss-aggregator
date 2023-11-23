package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi"
	"github.com/go-chi/cors"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/horriblename/rss-aggre/internal/database"
	"golang.org/x/crypto/bcrypt"

	// "github.com/go-chi/cors"
	"github.com/joho/godotenv"

	// we don't use the db driver directly, but we must import it
	"github.com/lib/pq"
	_ "github.com/lib/pq"
)

const (
	gGetPostDefaultLimit    = 20
	gFetchFeedInterval      = 60 * time.Second
	gAccessTokIssuer        = "rss-aggre.horriblename.site"
	gRefreshTokIssuer       = "rss-aggre.horriblename.site"
	gRefreshTokenExpiration = 1 * 60 * 60 * time.Second
	gAccessTokenExpiration  = 60 * 24 * 60 * 60 * time.Second
)

var (
	ErrBadAuthHeader     = errors.New("bad Authorization header")
	ErrUnauthorizedToken = errors.New("Unauthorized Token")
)

type serverConfig struct {
	port string
}

type apiConfig struct {
	queries   *database.Queries
	db        *sql.DB
	jwtSecret []byte
	ctx       context.Context
}

type authedHandler func(http.ResponseWriter, *http.Request, database.User)

func main() {
	var err error
	godotenv.Load()

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Print("missing env var $DATABASE_URL")
		os.Exit(1)
	}
	dbPasswordFile := os.Getenv("DATABASE_PASSWORD_FILE")
	if dbPasswordFile != "" {
		pwd, err := os.ReadFile(dbPasswordFile)
		if err != nil {
			log.Fatalf("error reading DATABASE_PASSWORD_FILE(%s): %s", dbPasswordFile, err)
		}

		// escape "'" and "\" + delete newlines
		sanitized := strings.NewReplacer("'", `\'`, `\`, `\\`, "\n", "").Replace((string(pwd)))
		dbURL = fmt.Sprintf("%s password='%s'", dbURL, sanitized)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "80"
	}

	cfg := serverConfig{port: port}
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Printf("opening db: %s", err)
	}

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtFile := os.Getenv("JWT_SECRET_FILE")
		if jwtFile == "" {
			log.Fatal("missing env var $JWT_SECRET")
		}

		secret, err := os.ReadFile(jwtFile)
		if err != nil {
			log.Fatalf("error reading $JWT_SECRET_FILE (%s): %s", jwtFile, err)
		}

		jwtSecret = string(secret)
	}
	apiCfg := apiConfig{database.New(db), db, []byte(jwtSecret), context.Background()}

	go fetchFeedLoop(apiCfg)

	err = startServer(cfg, apiCfg)
	if err != nil {
		log.Printf("error: %s", err)
		os.Exit(1)
	}
}

func startServer(serverCfg serverConfig, apiCfg apiConfig) error {
	router := chi.NewRouter()
	router.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"https://*", "http://*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"*"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	router.Mount("/v1", v1Router(apiCfg))

	server := http.Server{
		Handler: router,
		Addr:    ":" + serverCfg.port,
	}

	log.Printf("starting server...")
	return server.ListenAndServe()
}

func v1Router(apiCfg apiConfig) chi.Router {
	r := chi.NewRouter()
	r.Get("/readiness", getReadiness)
	r.Get("/err", getErr)
	r.Get("/users", apiCfg.middlewareAuth(apiCfg.getUsers))
	r.Post("/users", apiCfg.postUsers)
	r.Delete("/users", apiCfg.deleteUsers)
	r.Post("/login", apiCfg.postLogin)
	r.Post("/refresh", apiCfg.postRefresh)
	r.Post("/feeds", apiCfg.middlewareAuth(apiCfg.postFeeds))
	r.Get("/feeds", apiCfg.getFeeds)
	r.Post("/feed_follows", apiCfg.middlewareAuth(apiCfg.postFeedFollow))
	r.Delete("/feed_follows/{feed_follow_id}", feedFollowCtx(apiCfg.deleteFeedFollow))
	r.Get("/feed_follows", apiCfg.middlewareAuth(apiCfg.getFeedFollows))
	r.Get("/posts", apiCfg.middlewareAuth(apiCfg.getPosts))
	return r
}

func feedFollowCtx(next http.HandlerFunc) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ff_id_str := chi.URLParam(r, "feed_follow_id")
		ff_id, err := uuid.Parse(ff_id_str)
		if err != nil {
			respondWithError(w, http.StatusBadRequest, "Invalid Feed Follow ID")
			return
		}

		ctx := context.WithValue(r.Context(), "feed_follow_id", ff_id)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func getReadiness(w http.ResponseWriter, r *http.Request) {
	type readinessReply struct {
		Status string `json:"status"`
	}
	respondWithJSON(w, http.StatusOK, readinessReply{"ok"})
}

func getErr(w http.ResponseWriter, r *http.Request) {
	respondWithError(w, http.StatusInternalServerError, "Internal Server Error")
}

func (cfg *apiConfig) middlewareAuth(handler authedHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		auth := r.Header.Get("Authorization")
		if strings.HasPrefix(auth, "ApiKey ") {
			api_key := strings.TrimPrefix(auth, "ApiKey ")
			user, err := cfg.queries.GetUser(cfg.ctx, api_key)
			if err != nil {
				if err == sql.ErrNoRows {
					respondWithError(w, http.StatusUnauthorized, "Unrecognized API Key")
					return
				}
				log.Printf("middlewareAuth db error: %s", err)
				respondWithError(w, http.StatusInternalServerError, "Internal Server Error")
				return
			}

			handler(w, r, user)
		} else if strings.HasPrefix(auth, "Bearer ") {
			token, err := cfg.validateJWT(r)
			if err != nil {
				if err == ErrUnauthorizedToken {
					respondWithError(w, http.StatusUnauthorized, "Unauthorized Token")
				} else {
					respondWithError(w, http.StatusUnauthorized, "Bad Authorization Header")
				}
				return
			}

			subj, err := token.Claims.GetSubject()
			if err != nil {
				log.Printf("could not retrieve subject from valid JWT token: %s", err)
				respondWithError(w, http.StatusUnauthorized, "Unauthorized")
				return
			}
			user_id, err := uuid.Parse(subj)
			if err != nil {
				log.Printf("got invalid uuid as subject from valid JWT token(%s): %s", subj, err)
				respondWithError(w, http.StatusUnauthorized, "Unauthorized")
				return
			}

			user, err := cfg.queries.GetUserFromID(cfg.ctx, user_id)
			if err != nil {
				log.Printf("middlewareAuth get user from ID db error: %s", err)
				respondWithError(w, http.StatusInternalServerError, "DB Error")
				return
			}

			handler(w, r, user)
		} else {
			log.Printf("attempt to get user with bad Authorization: %s", auth)
			respondWithError(w, http.StatusUnauthorized, "Missing or Bad Authorization in header")
			return
		}
	}
}

func (cfg *apiConfig) getUsers(w http.ResponseWriter, r *http.Request, user database.User) {
	auth := r.Header.Get("Authorization")
	api_key, found := strings.CutPrefix(auth, "ApiKey ")
	if !found {
		log.Print("attempt to get user with bad Authorization")
		respondWithError(w, http.StatusBadRequest, "Missing or Bad Authorization in header")
		return
	}

	user, err := cfg.queries.GetUser(cfg.ctx, api_key)
	if err != nil {
		if err == sql.ErrNoRows {
			log.Printf("user not found %s", api_key)
			respondWithError(w, http.StatusBadRequest, "User not found")
			return
		}
		log.Printf("error getting user %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB error")
		return
	}

	userJSON := UserFromDB(&user)

	respondWithJSON(w, http.StatusOK, &userJSON)
}

func (cfg *apiConfig) postUsers(w http.ResponseWriter, r *http.Request) {
	type postUsersRequest struct {
		Name     string `json:"name"`
		Password string `json:"password"`
	}

	var requestBody postUsersRequest
	decoder := json.NewDecoder(r.Body)
	err := decoder.Decode(&requestBody)

	if err != nil {
		log.Printf("error decoding json: %s", err)
		respondWithError(w, http.StatusBadRequest, "Error decoding JSON")
		return
	}

	pwHash, err := bcrypt.GenerateFromPassword([]byte(requestBody.Password), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("bad password: is it too long? (more than 72 bytes)")
	}

	user, err := cfg.queries.CreateUser(cfg.ctx, database.CreateUserParams{
		ID:           uuid.New(),
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
		Name:         requestBody.Name,
		Passwordhash: pwHash,
	})

	if err != nil {
		if err, ok := err.(*pq.Error); ok {
			// constraint name specified in sql/schema/009_user_unique_name.sql
			if err.Constraint == "user_name_unique" {
				respondWithError(w, http.StatusUnauthorized, "Username unavailable")
				return
			}
		}

		log.Printf("error db: %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB error")
		return
	}

	respondWithJSON(w, http.StatusOK, &user)
}

func (cfg *apiConfig) deleteUsers(w http.ResponseWriter, r *http.Request) {
	type response struct {
		Status string `json:"status"`
	}
	type deleteUsersArgs struct {
		Name     string `json:"name"`
		Password string `json:"password"`
	}

	var req deleteUsersArgs
	decoder := json.NewDecoder(r.Body)
	err := decoder.Decode(&req)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Error decoding JSON")
		return
	}

	tx, err := cfg.db.Begin()
	if err != nil {
		log.Printf("db begin transaction: %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB Error")
		return
	}
	defer tx.Rollback()
	qtx := cfg.queries.WithTx(tx)

	user, err := qtx.GetUserFromName(cfg.ctx, req.Name)

	if err != nil {
		respondWithError(w, http.StatusUnauthorized, "User name does not exist")
		return
	}

	err = bcrypt.CompareHashAndPassword(user.Passwordhash, []byte(req.Password))
	if err != nil {
		respondWithError(w, http.StatusUnauthorized, "Wrong Password")
		return
	}

	err = qtx.DeleteUser(cfg.ctx, user.ID)
	if err != nil {
		log.Printf("db deleting user: %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB Error")
		return
	}

	err = tx.Commit()
	if err != nil {
		log.Printf("in deleteUsers: db commiting transaction: %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB Error")
		return
	}

	respondWithJSON(w, http.StatusOK, response{"ok"})
}

func (cfg *apiConfig) postLogin(w http.ResponseWriter, r *http.Request) {
	type postLoginRequest struct {
		Name     string `json:"name"`
		Password string `json:"password"`
	}

	var req postLoginRequest
	decoder := json.NewDecoder(r.Body)
	err := decoder.Decode(&req)
	if err != nil {
		// log.Printf("error decoding json")
		respondWithError(w, http.StatusBadRequest, "Error decoding JSON")
		return
	}

	user, err := cfg.queries.GetUserFromName(cfg.ctx, req.Name)
	if err != nil {
		respondWithError(w, http.StatusUnauthorized, "User name does not exist")
		return
	}

	err = bcrypt.CompareHashAndPassword(user.Passwordhash, []byte(req.Password))
	if err != nil {
		respondWithError(w, http.StatusUnauthorized, "Wrong Password")
		return
	}

	accessTokClaims := newAccessTokenClaims(user.ID.String())

	refreshTokClaims := newRefreshTokenClaims(user.ID.String())

	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessTokClaims)
	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshTokClaims)

	accessTokStr, err := accessToken.SignedString(cfg.jwtSecret)
	if err != nil {
		fmt.Printf("signing JWT token: %s\n", err)
		respondWithError(w, http.StatusInternalServerError, "Internal Error")
		return
	}

	refreshTokStr, err := refreshToken.SignedString(cfg.jwtSecret)
	if err != nil {
		fmt.Printf("signing JWT token: %s\n", err)
		respondWithError(w, http.StatusInternalServerError, "Internal Error")
		return
	}

	resp := LoginResponse{
		UserID:       user.ID,
		AccessToken:  accessTokStr,
		RefreshToken: refreshTokStr,
	}

	respondWithJSON(w, http.StatusOK, resp)
}

func (cfg *apiConfig) postRefresh(w http.ResponseWriter, r *http.Request) {
	token, err := cfg.validateJWT(r)
	if err != nil {
		if errors.Is(err, ErrUnauthorizedToken) {
			respondWithError(w, http.StatusUnauthorized, "Invalid Token")
		} else {
			respondWithError(w, http.StatusUnauthorized, `Malformed "Authorization" in Header`)
		}
		return
	}
	auth := r.Header.Get("Authorization")

	const prefix = "Bearer "
	if !strings.HasPrefix(auth, prefix) {
		respondWithError(w, http.StatusBadRequest, `Malformed "Authorization" in Header`)
		return
	}

	tokStr := strings.TrimPrefix(auth, prefix)
	if isRevoked, err := cfg.queries.TokenIsRevoked(cfg.ctx, tokStr); err != nil {
		log.Printf("checking if token is revoked, db error: %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB Error")
		return
	} else if isRevoked == 1 {
		respondWithError(w, http.StatusUnauthorized, "Invalid Token")
		return
	}

	if issuer, err := token.Claims.GetIssuer(); err != nil {
		log.Printf("valid JWT without issuer (%s)", tokStr)
		respondWithError(w, http.StatusUnauthorized, "Could Not Get Issuer")
		return
	} else if issuer != gRefreshTokIssuer {
		log.Printf("valid JWT wrong issuer (%s)", tokStr)
		respondWithError(w, http.StatusUnauthorized, "Wrong Issuer")
		return
	}

	subj, err := token.Claims.GetSubject()
	if err != nil {
		respondWithError(w, http.StatusUnauthorized, "Could Not Get Subject")
		return
	}

	accessTokClaims := newAccessTokenClaims(subj)
	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessTokClaims)

	accessTokStr, err := accessToken.SignedString(cfg.jwtSecret)
	if err != nil {
		log.Printf("secret: %v", cfg.jwtSecret)
		log.Printf("signing JWT token: %s", err)
		respondWithError(w, http.StatusInternalServerError, "Internal Error")
		return
	}

	resp := struct {
		Token string `json:"token"`
	}{accessTokStr}

	respondWithJSON(w, http.StatusOK, resp)
}

func (cfg *apiConfig) postFeeds(w http.ResponseWriter, r *http.Request, user database.User) {
	type postFeedsRequest struct {
		Name string `json:"name"`
		Url  string `json:"url"`
	}

	var req postFeedsRequest
	decoder := json.NewDecoder(r.Body)
	err := decoder.Decode(&req)
	if err != nil {
		// log.Printf("error decoding json")
		respondWithError(w, http.StatusBadRequest, "Error decoding JSON")
		return
	}

	tx, err := cfg.db.Begin()
	if err != nil {
		log.Printf("db begin transaction: %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB Error")
		return
	}
	defer tx.Rollback()
	qtx := cfg.queries.WithTx(tx)

	feed, err := qtx.CreateFeed(cfg.ctx, database.CreateFeedParams{
		ID:        uuid.New(),
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
		Name:      req.Name,
		Url:       req.Url,
		UserID:    user.ID,
	})

	if err != nil {
		log.Printf("db creating feed: %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB error")
		return
	}

	if _, err := qtx.CreateFeedFollow(cfg.ctx, database.CreateFeedFollowParams{
		ID:        uuid.New(),
		FeedID:    feed.ID,
		UserID:    user.ID,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}); err != nil {
		log.Printf("db creating feed_follow: %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB error")
		return
	}

	err = tx.Commit()
	if err != nil {
		log.Printf("db commiting transaction: %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB Error")
		return
	}

	respondWithJSON(w, http.StatusOK, &feed)
}

func (cfg *apiConfig) getFeeds(w http.ResponseWriter, r *http.Request) {
	type queryParams struct {
		includeFollow bool
	}

	params := queryParams{
		includeFollow: r.URL.Query().Get("follows") == "1",
	}

	if params.includeFollow {
		cfg.middlewareAuth(cfg.getFeedsWithFollows)(w, r)
		return
	}

	feeds, err := cfg.queries.GetFeeds(cfg.ctx)
	if err != nil {
		log.Printf("db get feeds: %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB error")
		return
	}

	if feeds == nil {
		feeds = make([]database.Feed, 0)
	}
	respondWithJSON(w, http.StatusOK, feeds)
}

func (cfg *apiConfig) getFeedsWithFollows(w http.ResponseWriter, r *http.Request, user database.User) {
	feeds, err := cfg.queries.GetFeedsWithFollows(cfg.ctx, user.ID)
	if err != nil {
		log.Printf("db get feeds: %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB error")
		return
	}

	feedsJSON := make([]FeedWithFollows, 0, len(feeds))
	for _, feed := range feeds {
		feedsJSON = append(feedsJSON, FeedWithFollowsFromDB(&feed))
	}
	respondWithJSON(w, http.StatusOK, feedsJSON)
}

func (cfg *apiConfig) postFeedFollow(w http.ResponseWriter, r *http.Request, user database.User) {
	type postFeedFollowReq struct {
		FeedID uuid.UUID `json:"feed_id"`
	}

	var args postFeedFollowReq
	err := json.NewDecoder(r.Body).Decode(&args)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Error decoding JSON")
		return
	}

	ff, err := cfg.queries.CreateFeedFollow(cfg.ctx, database.CreateFeedFollowParams{
		ID:        uuid.New(),
		FeedID:    args.FeedID,
		UserID:    user.ID,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	})

	if err != nil {
		log.Printf("db creating feed follow: %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB Error")
		return
	}

	respondWithJSON(w, http.StatusOK, ff)
}

func (cfg *apiConfig) deleteFeedFollow(w http.ResponseWriter, r *http.Request) {
	ff_id := r.Context().Value("feed_follow_id")
	if ff_id, ok := ff_id.(uuid.UUID); ok {

		_, err := cfg.queries.DeleteFeedFollow(cfg.ctx, ff_id)
		if err != nil {
			if err == sql.ErrNoRows {
				respondWithError(w, http.StatusNotFound, "Feed Follow not found")
				return
			}
			respondWithError(w, http.StatusInternalServerError, "DB Error")
			return
		}

		respondWithJSON(w, http.StatusOK, "ok")
		return
	} else {
		respondWithError(w, http.StatusBadRequest, "Expected feed follow id")
		return
	}
}

func (cfg *apiConfig) getFeedFollows(w http.ResponseWriter, r *http.Request, user database.User) {
	ffs, err := cfg.queries.GetFeedFollowsOfUser(cfg.ctx, user.ID)
	if err != nil {
		if err == sql.ErrNoRows {
			respondWithError(w, http.StatusNotFound, "Feed follow not found")
		}
		log.Printf("db getting feed follows: %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB error")
		return
	}

	if ffs == nil {
		respondWithJSON(w, http.StatusOK, make([]database.FeedFollow, 0))
		return
	}
	respondWithJSON(w, http.StatusOK, ffs)
}

func (cfg *apiConfig) getPosts(w http.ResponseWriter, r *http.Request, user database.User) {
	type getPostsArgs struct {
		limit  int
		offset int
	}

	query := r.URL.Query()
	args := getPostsArgs{
		limit:  unwrapOr(strconv.Atoi(query.Get("limit")))(gGetPostDefaultLimit),
		offset: unwrapOr(strconv.Atoi(query.Get("offset")))(0),
	}

	if args.limit <= 0 {
		args.limit = gGetPostDefaultLimit
	}

	posts, err := cfg.queries.GetPostsByUser(cfg.ctx, database.GetPostsByUserParams{
		UserID: user.ID,
		Limit:  int32(args.limit),
		Offset: int32(args.offset),
	})

	if err != nil {
		log.Printf("db getting user posts: %s", err)
		respondWithError(w, http.StatusInternalServerError, "couldn't get user posts")
		return
	}

	postsJSON := make([]Post, 0, len(posts))
	for _, post := range posts {
		postsJSON = append(postsJSON, PostFromDB(&post))
	}

	respondWithJSON(w, http.StatusOK, postsJSON)
}

// returns ErrBadAuthHeader for malformed "Authorization" headers
//
// returns a possibly wrapped ErrUnauthorizedToken if the token is not valid (expired/invalid signature)
//
// forwards any other jwt.Err*
func (cfg *apiConfig) validateJWT(req *http.Request) (*jwt.Token, error) {
	// header format:
	//	  Authorization: Bearer <token>
	auth := req.Header.Get("Authorization")

	const prefix = "Bearer "
	if !strings.HasPrefix(auth, prefix) {
		return nil, ErrBadAuthHeader
	}
	tokStr := strings.TrimPrefix(auth, prefix)
	claims := jwt.RegisteredClaims{}

	token, err := jwt.ParseWithClaims(tokStr, &claims, func(token *jwt.Token) (interface{}, error) {
		return cfg.jwtSecret, nil
	})
	if err != nil {
		if err == jwt.ErrSignatureInvalid {
			return nil, fmt.Errorf("%w: Invalid Signature", ErrUnauthorizedToken)
		}
		return nil, fmt.Errorf("parsing JWT token: %w\n", err)
	}

	if !token.Valid {
		return nil, ErrUnauthorizedToken
	}

	return token, nil
}

func newAccessTokenClaims(subject string) jwt.RegisteredClaims {
	return jwt.RegisteredClaims{
		Issuer:    gAccessTokIssuer,
		IssuedAt:  jwt.NewNumericDate(time.Now()),
		ExpiresAt: jwt.NewNumericDate(time.Now().Add(gAccessTokenExpiration)),
		Subject:   subject,
	}
}

func newRefreshTokenClaims(subject string) jwt.RegisteredClaims {
	return jwt.RegisteredClaims{
		Issuer:    gRefreshTokIssuer,
		IssuedAt:  jwt.NewNumericDate(time.Now()),
		ExpiresAt: jwt.NewNumericDate(time.Now().Add(gRefreshTokenExpiration)),
		Subject:   subject,
	}
}

// Ignores an error and uses a specified value instead
// usage:
// ```
// unwrapOr(strconv.Atoi("5"))(10)  // => 5
// unwrapOr(strconv.Atoi("n"))(10)  // => 10
// ```
func unwrapOr[T any](ans T, err error) func(T) T {
	if err == nil {
		return func(t T) T { return ans }
	} else {
		return func(t T) T { return t }
	}
}

// errors are logged not returned
func respondWithJSON(w http.ResponseWriter, status int, payload interface{}) {
	w.WriteHeader(status)
	encoder := json.NewEncoder(w)
	err := encoder.Encode(payload)
	if err != nil {
		log.Printf("encoding JSON: %s", err)
	}
}

func respondWithError(w http.ResponseWriter, status int, msg string) {
	type errMsg struct {
		Error string `json:"error"`
	}
	respondWithJSON(w, status, &errMsg{msg})
}
