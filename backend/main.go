package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/go-chi/chi"
	// "github.com/go-chi/cors"
	"github.com/joho/godotenv"
)

type serverConfig struct {
	port string
}

func main() {
	godotenv.Load()

	port := os.Getenv("PORT")
	if port == "" {
		port = "80"
	}

	cfg := serverConfig{port: port}

	err := startServer(cfg)
	if err != nil {
		log.Printf("error: %s", err)
		os.Exit(1)
	}
}

func startServer(serverCfg serverConfig) error {
	router := chi.NewRouter()
	// router.Use(cors.Handler())

	router.Mount("/v1", v1Router())

	server := http.Server{
		Handler: router,
		Addr:    "localhost:" + serverCfg.port,
	}

	return server.ListenAndServe()
}

func v1Router() chi.Router {
	r := chi.NewRouter()
	r.Get("/readiness", getReadiness)
	r.Get("/err", getErr)
	return r
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
