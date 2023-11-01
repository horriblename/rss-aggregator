package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/go-chi/chi"
	"github.com/go-chi/cors"
	"github.com/google/uuid"
	"github.com/horriblename/rss-aggre/internal/database"

	// "github.com/go-chi/cors"
	"github.com/joho/godotenv"

	// we don't use the db driver directly, but we must import it
	_ "github.com/lib/pq"
)

const (
	gGetPostDefaultLimit = 20
	gFetchFeedInterval   = 60 * time.Second
)

type serverConfig struct {
	port string
}

type apiConfig struct {
	queries *database.Queries
	db      *sql.DB
	ctx     context.Context
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

	port := os.Getenv("PORT")
	if port == "" {
		port = "80"
	}

	cfg := serverConfig{port: port}
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Printf("opening db: %s", err)
	}
	apiCfg := apiConfig{database.New(db), db, context.Background()}

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
		Addr:    "localhost:" + serverCfg.port,
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
		api_key, found := strings.CutPrefix(auth, "ApiKey ")
		if !found {
			log.Print("attempt to get user with bad Authorization")
			respondWithError(w, http.StatusUnauthorized, "Missing or Bad Authorization in header")
			return
		}

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

	respondWithJSON(w, http.StatusOK, &user)
}

func (cfg *apiConfig) postUsers(w http.ResponseWriter, r *http.Request) {
	type postUsersRequest struct {
		Name string `json:"name"`
	}

	var requestBody postUsersRequest
	decoder := json.NewDecoder(r.Body)
	err := decoder.Decode(&requestBody)

	if err != nil {
		log.Printf("error decoding json: %s", err)
		respondWithError(w, http.StatusBadRequest, "Error decoding JSON")
		return
	}

	user, err := cfg.queries.CreateUser(cfg.ctx, database.CreateUserParams{
		ID:        uuid.New(),
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
		Name:      requestBody.Name,
	})

	if err != nil {
		log.Printf("error db: %s", err)
		respondWithError(w, http.StatusInternalServerError, "DB error")
		return
	}

	respondWithJSON(w, http.StatusOK, &user)
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
		respondWithJSON(w, http.StatusOK, make([]int, 0))
		return
	}
	respondWithJSON(w, http.StatusOK, ffs)
}

func (cfg *apiConfig) getPosts(w http.ResponseWriter, r *http.Request, user database.User) {
	type getPostsArgs struct {
		Limit int `json:"limit,omit_empty"`
	}

	var args getPostsArgs
	// FIXME: GET requests _should_ not accept a body - if possible, use query string parameters instead
	_ = json.NewDecoder(r.Body).Decode(&args)

	if args.Limit == 0 {
		args.Limit = gGetPostDefaultLimit
	}

	posts, err := cfg.queries.GetPostsByUser(cfg.ctx, database.GetPostsByUserParams{
		UserID: user.ID,
		Limit:  int32(args.Limit),
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
