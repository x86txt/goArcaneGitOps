package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const (
	colorReset  = "\033[0m"
	colorRed    = "\033[31m"
	colorGreen  = "\033[32m"
	colorYellow = "\033[33m"
	colorBlue   = "\033[34m"
)

type Config struct {
	RepoPath      string
	ArcaneBaseURL string // Arcane API base URL (e.g., http://localhost:3552)
	ArcaneAPIKey  string // Arcane API key
	ArcaneEnvID   string
	LogFile       string
	GitAuthMethod string // Authentication method: "ssh" or "https"
	GitSSHKeyPath string // SSH private key for git operations (if using SSH)
	GitHTTPSToken string // GitHub personal access token (if using HTTPS)
}

// Arcane API types
type ArcaneProject struct {
	ID             string `json:"id"`
	Name           string `json:"name"`
	Status         string `json:"status"`
	StatusReason   string `json:"statusReason"`
	DirName        string `json:"dirName"`
	Path           string `json:"path"`
	ComposeContent string `json:"composeContent"`
	EnvContent     string `json:"envContent"`
	CreatedAt      string `json:"createdAt"`
	UpdatedAt      string `json:"updatedAt"`
}

type ArcanePagination struct {
	CurrentPage     int `json:"currentPage"`
	GrandTotalItems int `json:"grandTotalItems"`
	ItemsPerPage    int `json:"itemsPerPage"`
	TotalItems      int `json:"totalItems"`
	TotalPages      int `json:"totalPages"`
}

// Paginated response wrapper
type ArcanePaginatedResponse struct {
	Success    bool             `json:"success"`
	Data       []ArcaneProject  `json:"data"`
	Pagination ArcanePagination `json:"pagination"`
}

type ArcaneCreateResponse struct {
	Success bool `json:"success"`
	Data    struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"data"`
}

type ArcaneAPIClient struct {
	BaseURL    string
	APIKey     string
	EnvID      string
	HTTPClient *http.Client
}

func NewArcaneAPIClient(baseURL, apiKey, envID string) *ArcaneAPIClient {
	return &ArcaneAPIClient{
		BaseURL: strings.TrimRight(baseURL, "/"),
		APIKey:  apiKey,
		EnvID:   envID,
		HTTPClient: &http.Client{
			Timeout: 60 * time.Second,
		},
	}
}

func (c *ArcaneAPIClient) doRequest(method, endpoint string, body interface{}) ([]byte, error) {
	url := fmt.Sprintf("%s%s", c.BaseURL, endpoint)

	var reqBody io.Reader
	if body != nil {
		jsonData, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal request body: %w", err)
		}
		reqBody = bytes.NewBuffer(jsonData)
	}

	req, err := http.NewRequest(method, url, reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("X-Api-Key", c.APIKey)
	// Arcane API docs sometimes show API keys used as Bearer tokens.
	// Setting both headers makes this client compatible across versions.
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", c.APIKey))
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer func() {
		_ = resp.Body.Close() // Ignore close errors
	}()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("API error (status %d): %s", resp.StatusCode, string(respBody))
	}

	return respBody, nil
}

func (c *ArcaneAPIClient) ListProjects() ([]ArcaneProject, error) {
	return c.listProjectsAll("")
}

func (c *ArcaneAPIClient) ProjectExists(projectName string) (bool, string, error) {
	projects, err := c.ListProjects()
	if err != nil {
		return false, "", err
	}

	for _, p := range projects {
		if p.Name == projectName {
			return true, p.ID, nil
		}
	}
	return false, "", nil
}

func (c *ArcaneAPIClient) FindProjectsByNameExact(projectName string) ([]ArcaneProject, error) {
	projects, err := c.listProjectsAll(projectName)
	if err != nil {
		return nil, err
	}

	var exact []ArcaneProject
	for _, p := range projects {
		if p.Name == projectName {
			exact = append(exact, p)
		}
	}
	return exact, nil
}

func (c *ArcaneAPIClient) listProjectsAll(search string) ([]ArcaneProject, error) {
	const pageSize = 50
	start := 0
	var all []ArcaneProject

	for {
		endpointURL := &url.URL{
			Path: fmt.Sprintf("/api/environments/%s/projects", c.EnvID),
		}
		q := endpointURL.Query()
		q.Set("start", fmt.Sprintf("%d", start))
		q.Set("limit", fmt.Sprintf("%d", pageSize))
		if search != "" {
			q.Set("search", search)
		}
		endpointURL.RawQuery = q.Encode()

		respBody, err := c.doRequest("GET", endpointURL.String(), nil)
		if err != nil {
			return nil, err
		}

		var paginatedResp ArcanePaginatedResponse
		if err := json.Unmarshal(respBody, &paginatedResp); err != nil {
			return nil, fmt.Errorf("failed to parse projects response: %w\nBody: %s", err, string(respBody))
		}

		all = append(all, paginatedResp.Data...)

		// Stop conditions:
		// - last page (returned fewer than requested)
		// - pagination reports total and we've collected enough
		if len(paginatedResp.Data) < pageSize {
			break
		}

		total := 0
		if paginatedResp.Pagination.GrandTotalItems > 0 {
			total = paginatedResp.Pagination.GrandTotalItems
		} else if paginatedResp.Pagination.TotalItems > 0 {
			total = paginatedResp.Pagination.TotalItems
		}
		if total > 0 && len(all) >= total {
			break
		}

		start += pageSize
	}

	return all, nil
}

func (c *ArcaneAPIClient) CreateProject(name, composeContent, envContent string) (string, error) {
	endpoint := fmt.Sprintf("/api/environments/%s/projects", c.EnvID)

	reqBody := map[string]interface{}{
		"name":           name,
		"composeContent": composeContent,
	}
	if envContent != "" {
		reqBody["envContent"] = envContent
	}

	respBody, err := c.doRequest("POST", endpoint, reqBody)
	if err != nil {
		return "", err
	}

	var createResp ArcaneCreateResponse
	if err := json.Unmarshal(respBody, &createResp); err != nil {
		return "", fmt.Errorf("failed to parse create response: %w", err)
	}

	if createResp.Data.ID != "" {
		return createResp.Data.ID, nil
	}
	return name, nil // Fallback to name as ID
}

func (c *ArcaneAPIClient) UpdateProject(projectID, composeContent, envContent string) error {
	endpoint := fmt.Sprintf("/api/environments/%s/projects/%s", c.EnvID, projectID)

	reqBody := map[string]interface{}{}
	if composeContent != "" {
		reqBody["composeContent"] = composeContent
	}
	if envContent != "" {
		reqBody["envContent"] = envContent
	}

	_, err := c.doRequest("PUT", endpoint, reqBody)
	return err
}

func (c *ArcaneAPIClient) StartProject(projectID string) error {
	endpoint := fmt.Sprintf("/api/environments/%s/projects/%s/up", c.EnvID, projectID)
	_, err := c.doRequest("POST", endpoint, nil)
	return err
}

func (c *ArcaneAPIClient) DeployProject(projectID string) error {
	endpoint := fmt.Sprintf("/api/environments/%s/projects/%s/deploy", c.EnvID, projectID)
	reqBody := map[string]bool{"pull": true}
	_, err := c.doRequest("POST", endpoint, reqBody)
	return err
}

func (c *ArcaneAPIClient) RedeployProject(projectID string) error {
	// Try deploy first, then redeploy
	endpoint := fmt.Sprintf("/api/environments/%s/projects/%s/redeploy", c.EnvID, projectID)
	_, err := c.doRequest("POST", endpoint, nil)
	return err
}

type GitStatus struct {
	Ahead          int
	Behind         int
	HasLocalChange bool
}

func main() {
	config := Config{
		RepoPath:      os.Getenv("COMPOSE_REPO_PATH"),
		ArcaneBaseURL: os.Getenv("ARCANE_BASE_URL"),
		ArcaneAPIKey:  os.Getenv("ARCANE_API_KEY"),
		ArcaneEnvID:   getEnvOrDefault("ARCANE_ENV_ID", "0"),
		LogFile:       getEnvOrDefault("LOG_FILE", "/var/log/sync-tool.log"),
		GitAuthMethod: getEnvOrDefault("GIT_AUTH_METHOD", "ssh"),
		GitSSHKeyPath: os.Getenv("GIT_SSH_KEY_PATH"),
		GitHTTPSToken: os.Getenv("GIT_HTTPS_TOKEN"),
	}

	// Validate configuration
	if config.RepoPath == "" {
		log.Fatal("COMPOSE_REPO_PATH environment variable is required")
	}
	if config.ArcaneBaseURL == "" {
		log.Fatal("ARCANE_BASE_URL environment variable is required (e.g., http://localhost:3552)")
	}
	if config.ArcaneAPIKey == "" {
		log.Fatal("ARCANE_API_KEY environment variable is required")
	}

	// Setup git authentication based on configured method
	setupGitAuth(config.GitAuthMethod, config.GitSSHKeyPath, config.GitHTTPSToken)

	// Setup logging
	setupLogging(config.LogFile)

	logInfo("Starting compose sync check")
	logInfo(fmt.Sprintf("Repository: %s", config.RepoPath))

	// Change to repo directory
	if err := os.Chdir(config.RepoPath); err != nil {
		logError(fmt.Sprintf("Failed to change to repository directory: %v", err))
		os.Exit(1)
	}

	// Fetch latest from remote
	logInfo("Fetching from remote...")
	if err := runGitCommand("fetch", "origin"); err != nil {
		logError(fmt.Sprintf("Failed to fetch from remote: %v", err))
		os.Exit(1)
	}

	// Get current branch
	branch, err := getCurrentBranch()
	if err != nil {
		logError(fmt.Sprintf("Failed to get current branch: %v", err))
		os.Exit(1)
	}
	logInfo(fmt.Sprintf("Current branch: %s", branch))

	// Check git status
	status, err := getGitStatus(branch)
	if err != nil {
		logError(fmt.Sprintf("Failed to get git status: %v", err))
		os.Exit(1)
	}

	// Get current commit before any changes
	oldCommit, err := getCurrentCommit()
	if err != nil {
		logError(fmt.Sprintf("Failed to get current commit: %v", err))
		os.Exit(1)
	}

	changesOccurred := false

	// Handle diverged state (both ahead and behind)
	// GitOps principle: Remote is always the source of truth
	if status.Ahead > 0 && status.Behind > 0 {
		logWarning(fmt.Sprintf("Local has diverged (ahead by %d, behind by %d)", status.Ahead, status.Behind))
		logWarning("Remote is source of truth - discarding local commits and syncing to remote")

		// Discard local changes and commits, force sync to remote
		if err := runGitCommand("fetch", "origin", branch); err != nil {
			logError(fmt.Sprintf("Failed to fetch: %v", err))
			os.Exit(1)
		}
		if err := runGitCommand("reset", "--hard", fmt.Sprintf("origin/%s", branch)); err != nil {
			logError(fmt.Sprintf("Failed to reset to remote: %v", err))
			os.Exit(1)
		}
		// Clean untracked files but preserve local env files
		if err := runGitCommand("clean", "-fd", "-e", ".env.global", "-e", "*.env.local", "-e", ".env"); err != nil {
			logWarning(fmt.Sprintf("Failed to clean untracked files: %v", err))
		}
		logSuccess("Successfully force-synced to remote")
		changesOccurred = true
	} else if status.Ahead > 0 {
		// Only ahead (not behind) - this is unusual for GitOps but handle it
		logWarning(fmt.Sprintf("Local is ahead by %d commits (unusual for GitOps)", status.Ahead))
		logWarning("Remote is source of truth - discarding local commits")

		if err := runGitCommand("fetch", "origin", branch); err != nil {
			logError(fmt.Sprintf("Failed to fetch: %v", err))
			os.Exit(1)
		}
		if err := runGitCommand("reset", "--hard", fmt.Sprintf("origin/%s", branch)); err != nil {
			logError(fmt.Sprintf("Failed to reset to remote: %v", err))
			os.Exit(1)
		}
		logSuccess("Successfully reset to remote")
		// No changesOccurred since we're just discarding local, remote hasn't changed
	}

	// Handle behind (need to pull) - only if not already handled in diverged case
	if status.Behind > 0 && status.Ahead == 0 {
		logInfo(fmt.Sprintf("Local is behind by %d commits, pulling...", status.Behind))

		// GitOps principle: Remote is the source of truth
		// Discard any local changes and force sync to remote
		if status.HasLocalChange {
			logWarning("Local changes detected, discarding (remote is source of truth)...")
			// Reset any staged changes
			if err := runGitCommand("reset", "--hard", "HEAD"); err != nil {
				logWarning(fmt.Sprintf("Failed to reset HEAD: %v", err))
			}
			// Clean untracked files but preserve local env files
			if err := runGitCommand("clean", "-fd", "-e", ".env.global", "-e", "*.env.local", "-e", ".env"); err != nil {
				logWarning(fmt.Sprintf("Failed to clean untracked files: %v", err))
			}
		}

		// Force local branch to match remote exactly
		if err := runGitCommand("fetch", "origin", branch); err != nil {
			logError(fmt.Sprintf("Failed to fetch: %v", err))
			os.Exit(1)
		}

		// Reset local branch to match remote
		if err := runGitCommand("reset", "--hard", fmt.Sprintf("origin/%s", branch)); err != nil {
			logError(fmt.Sprintf("Failed to reset to remote: %v", err))
			os.Exit(1)
		}
		logSuccess("Successfully synced to remote (force reset)")
		changesOccurred = true
	}

	// If both ahead and behind, we already handled it above
	// The pull with rebase should handle this scenario

	// Create Arcane API client
	arcane := NewArcaneAPIClient(config.ArcaneBaseURL, config.ArcaneAPIKey, config.ArcaneEnvID)

	// Get list of projects on disk
	diskProjects, err := listDiskProjects(config)
	if err != nil {
		logError(fmt.Sprintf("Failed to list disk projects: %v", err))
		os.Exit(1)
	}
	logInfo(fmt.Sprintf("Found %d project(s) on disk", len(diskProjects)))

	// Get list of projects in Arcane
	arcaneProjects, err := arcane.ListProjects()
	if err != nil {
		logWarning(fmt.Sprintf("Could not list Arcane projects: %v", err))
		arcaneProjects = []ArcaneProject{} // Continue with empty list
	}
	logInfo(fmt.Sprintf("Found %d project(s) in Arcane", len(arcaneProjects)))

	// Index Arcane projects by name (Arcane can contain duplicates)
	arcaneProjectsByName := make(map[string][]ArcaneProject)
	for _, p := range arcaneProjects {
		arcaneProjectsByName[p.Name] = append(arcaneProjectsByName[p.Name], p)
	}

	// Warn about duplicates to prevent surprising behavior
	for name, projects := range arcaneProjectsByName {
		if len(projects) > 1 {
			var ids []string
			for _, p := range projects {
				ids = append(ids, p.ID)
			}
			logWarning(fmt.Sprintf("Multiple Arcane projects share the same name '%s' (IDs: %s). sync-tool will only operate on one; please delete duplicates in Arcane UI.", name, strings.Join(ids, ", ")))
		}
	}

	// Determine which projects need action
	var projectsToCreate []string
	var projectsToSync []string

	// Check if git changed
	var changedProjects map[string]string
	if changesOccurred {
		newCommit, err := getCurrentCommit()
		if err != nil {
			logError(fmt.Sprintf("Failed to get new commit: %v", err))
			os.Exit(1)
		}
		changedProjects = detectChangedProjects(oldCommit, newCommit, config)
	} else {
		changedProjects = make(map[string]string)
	}

	// Compare disk to Arcane - disk is source of truth
	for _, diskProject := range diskProjects {
		if len(arcaneProjectsByName[diskProject]) == 0 {
			// Project exists on disk but not in Arcane - needs to be created
			projectsToCreate = append(projectsToCreate, diskProject)
		} else if _, changed := changedProjects[diskProject]; changed {
			// Project exists in both, but was changed in git - needs to be synced
			projectsToSync = append(projectsToSync, diskProject)
		}
	}

	if len(projectsToCreate) == 0 && len(projectsToSync) == 0 {
		logSuccess("All projects are in sync, no changes needed")
		return
	}

	// Create missing projects
	if len(projectsToCreate) > 0 {
		logInfo(fmt.Sprintf("Creating %d new project(s) in Arcane...", len(projectsToCreate)))
		for _, projectName := range projectsToCreate {
			projectPath := filepath.Join(config.RepoPath, projectName)
			composeFilePath := findComposeFile(projectPath)
			if composeFilePath == "" {
				logWarning(fmt.Sprintf("No compose file found for project %s, skipping", projectName))
				continue
			}

			// Read compose file content
			composeContent, err := os.ReadFile(composeFilePath)
			if err != nil {
				logError(fmt.Sprintf("Failed to read compose file for project %s: %v", projectName, err))
				continue
			}

			// Read optional .env file
			envContent := ""
			envFilePath := filepath.Join(projectPath, ".env")
			if envData, err := os.ReadFile(envFilePath); err == nil {
				envContent = string(envData)
			}

			// Guard: double-check with server-side search to avoid creating duplicates
			existing, err := arcane.FindProjectsByNameExact(projectName)
			if err != nil {
				logWarning(fmt.Sprintf("Could not verify whether project %s exists (will attempt create): %v", projectName, err))
			} else if len(existing) > 0 {
				var ids []string
				for _, p := range existing {
					ids = append(ids, p.ID)
				}
				logWarning(fmt.Sprintf("Project %s already exists in Arcane (IDs: %s). Skipping create to avoid duplicates.", projectName, strings.Join(ids, ", ")))
				arcaneProjectsByName[projectName] = existing
				continue
			}

			logInfo(fmt.Sprintf("Creating project: %s", projectName))
			projectID, err := arcane.CreateProject(projectName, string(composeContent), envContent)
			if err != nil {
				logError(fmt.Sprintf("Failed to create project %s: %v", projectName, err))
				continue
			}
			logSuccess(fmt.Sprintf("Created project: %s (ID: %s)", projectName, projectID))

			// Start the newly created project
			logInfo(fmt.Sprintf("Starting project: %s", projectName))
			if err := arcane.StartProject(projectID); err != nil {
				logWarning(fmt.Sprintf("Failed to start project %s (ID: %s): %v", projectName, projectID, err))
				// Try redeploy as fallback
				if err := arcane.RedeployProject(projectID); err != nil {
					logError(fmt.Sprintf("Failed to redeploy project %s (ID: %s): %v", projectName, projectID, err))
				} else {
					logSuccess(fmt.Sprintf("Redeployed project: %s", projectName))
				}
			} else {
				logSuccess(fmt.Sprintf("Started project: %s", projectName))
			}

			// Update our in-memory index so the rest of the run can resolve IDs
			arcaneProjectsByName[projectName] = []ArcaneProject{{ID: projectID, Name: projectName}}
		}
	}

	// Sync changed projects
	if len(projectsToSync) > 0 {
		logInfo(fmt.Sprintf("Syncing %d changed project(s)...", len(projectsToSync)))
		for _, projectName := range projectsToSync {
			projectID := projectName
			if candidates := arcaneProjectsByName[projectName]; len(candidates) > 0 {
				projectID = selectPreferredProjectID(candidates)
			} else {
				logWarning(fmt.Sprintf("Could not resolve Arcane project ID for %s, using name as fallback", projectName))
			}

			projectPath := filepath.Join(config.RepoPath, projectName)
			composeFilePath := findComposeFile(projectPath)
			if composeFilePath == "" {
				logWarning(fmt.Sprintf("No compose file found for project %s, skipping sync", projectName))
				continue
			}

			// Read compose file content
			composeContent, err := os.ReadFile(composeFilePath)
			if err != nil {
				logError(fmt.Sprintf("Failed to read compose file for project %s: %v", projectName, err))
				continue
			}

			// Read optional .env file
			envContent := ""
			envFilePath := filepath.Join(projectPath, ".env")
			if envData, err := os.ReadFile(envFilePath); err == nil {
				envContent = string(envData)
			}

			// Update project configuration in Arcane
			logInfo(fmt.Sprintf("Updating project configuration: %s", projectName))
			if err := arcane.UpdateProject(projectID, string(composeContent), envContent); err != nil {
				logWarning(fmt.Sprintf("Failed to update project %s (ID: %s) config: %v", projectName, projectID, err))
			}

			// Redeploy the project
			logInfo(fmt.Sprintf("Redeploying project: %s", projectName))
			if err := arcane.RedeployProject(projectID); err != nil {
				logError(fmt.Sprintf("Failed to redeploy project %s (ID: %s): %v", projectName, projectID, err))
			} else {
				logSuccess(fmt.Sprintf("Redeployed project: %s", projectName))
			}
		}
	}

	logSuccess("Compose sync completed successfully!")
}

func listDiskProjects(config Config) ([]string, error) {
	var projects []string

	entries, err := os.ReadDir(config.RepoPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read projects directory: %w", err)
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		// Skip hidden directories and syncTool
		if strings.HasPrefix(entry.Name(), ".") || entry.Name() == "syncTool" {
			continue
		}

		projectPath := filepath.Join(config.RepoPath, entry.Name())

		// Check if this folder contains a compose file
		if findComposeFile(projectPath) != "" {
			projects = append(projects, entry.Name())
		}
	}

	return projects, nil
}

func findComposeFile(projectPath string) string {
	composeFiles := []string{"compose.yaml", "compose.yml", "docker-compose.yaml", "docker-compose.yml"}
	for _, cf := range composeFiles {
		fullPath := filepath.Join(projectPath, cf)
		if _, err := os.Stat(fullPath); err == nil {
			return fullPath
		}
	}
	return ""
}

func selectPreferredProjectID(candidates []ArcaneProject) string {
	if len(candidates) == 0 {
		return ""
	}
	if len(candidates) == 1 {
		return candidates[0].ID
	}

	// Prefer the most recently updated project (best effort).
	best := candidates[0]
	bestTime := parseArcaneTime(best.UpdatedAt)
	if bestTime.IsZero() {
		bestTime = parseArcaneTime(best.CreatedAt)
	}

	for _, c := range candidates[1:] {
		t := parseArcaneTime(c.UpdatedAt)
		if t.IsZero() {
			t = parseArcaneTime(c.CreatedAt)
		}
		if !t.IsZero() && (bestTime.IsZero() || t.After(bestTime)) {
			best = c
			bestTime = t
		}
	}

	if best.ID != "" {
		return best.ID
	}
	// Fallback
	return candidates[0].ID
}

func parseArcaneTime(value string) time.Time {
	value = strings.TrimSpace(value)
	if value == "" {
		return time.Time{}
	}
	if t, err := time.Parse(time.RFC3339Nano, value); err == nil {
		return t
	}
	if t, err := time.Parse(time.RFC3339, value); err == nil {
		return t
	}
	return time.Time{}
}

func getCurrentBranch() (string, error) {
	cmd := exec.Command("git", "rev-parse", "--abbrev-ref", "HEAD")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

func getGitStatus(branch string) (*GitStatus, error) {
	status := &GitStatus{}

	// Get ahead/behind counts
	cmd := exec.Command("git", "rev-list", "--left-right", "--count", fmt.Sprintf("origin/%s...HEAD", branch))
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to get rev-list: %w", err)
	}

	// Parse output: "behind ahead"
	counts := strings.Fields(strings.TrimSpace(string(output)))
	if len(counts) == 2 {
		if _, err := fmt.Sscanf(counts[0], "%d", &status.Behind); err != nil {
			logWarning(fmt.Sprintf("failed to parse behind count: %v", err))
		}
		if _, err := fmt.Sscanf(counts[1], "%d", &status.Ahead); err != nil {
			logWarning(fmt.Sprintf("failed to parse ahead count: %v", err))
		}
	}

	// Check for local changes
	cmd = exec.Command("git", "status", "--porcelain")
	output, err = cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to check status: %w", err)
	}
	status.HasLocalChange = len(strings.TrimSpace(string(output))) > 0

	return status, nil
}

func runGitCommand(args ...string) error {
	cmd := exec.Command("git", args...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	cmd.Stdout = os.Stdout

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("%w: %s", err, stderr.String())
	}
	return nil
}

func getCurrentCommit() (string, error) {
	cmd := exec.Command("git", "rev-parse", "HEAD")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

func detectChangedProjects(oldCommit, newCommit string, config Config) map[string]string {
	changedProjects := make(map[string]string)

	// If commits are the same, no changes
	if oldCommit == newCommit {
		return changedProjects
	}

	// Get list of changed files between commits
	cmd := exec.Command("git", "diff", "--name-only", oldCommit, newCommit)
	output, err := cmd.Output()
	if err != nil {
		logError(fmt.Sprintf("Failed to get changed files: %v", err))
		return changedProjects
	}

	changedFiles := strings.Split(strings.TrimSpace(string(output)), "\n")
	logInfo(fmt.Sprintf("Detected %d changed file(s)", len(changedFiles)))

	// Check each changed file
	for _, file := range changedFiles {
		file = strings.TrimSpace(file)
		if file == "" {
			continue
		}

		logInfo(fmt.Sprintf("Changed file: %s", file))

		// Check if this is a compose.yaml file
		filename := filepath.Base(file)
		if filename != "compose.yaml" && filename != "compose.yml" && filename != "docker-compose.yaml" && filename != "docker-compose.yml" {
			continue
		}

		// Get the parent directory (project folder name)
		dir := filepath.Dir(file)
		projectName := filepath.Base(dir)

		// The project name is simply the folder name (e.g., "zerobyte")
		// This matches the Arcane project name
		changedProjects[projectName] = projectName
		logInfo(fmt.Sprintf("Detected change in project: %s", projectName))
	}

	return changedProjects
}

func setupLogging(logFile string) {
	// Ensure log directory exists
	logDir := filepath.Dir(logFile)
	if err := os.MkdirAll(logDir, 0755); err != nil {
		log.Fatalf("Failed to create log directory: %v", err)
	}

	// Open log file
	f, err := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("Failed to open log file: %v", err)
	}

	// Set log output to both file and stdout
	log.SetOutput(f)
	log.SetFlags(log.LstdFlags)
}

func logInfo(msg string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	fmt.Printf("%s[INFO]%s %s - %s\n", colorBlue, colorReset, timestamp, msg)
	log.Printf("[INFO] %s", msg)
}

func logSuccess(msg string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	fmt.Printf("%s[SUCCESS]%s %s - %s\n", colorGreen, colorReset, timestamp, msg)
	log.Printf("[SUCCESS] %s", msg)
}

func logWarning(msg string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	fmt.Printf("%s[WARNING]%s %s - %s\n", colorYellow, colorReset, timestamp, msg)
	log.Printf("[WARNING] %s", msg)
}

func logError(msg string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	fmt.Printf("%s[ERROR]%s %s - %s\n", colorRed, colorReset, timestamp, msg)
	log.Printf("[ERROR] %s", msg)
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func setupGitAuth(authMethod, sshKeyPath, httpsToken string) {
	authMethod = strings.ToLower(authMethod)

	switch authMethod {
	case "ssh":
		setupGitSSH(sshKeyPath)
	case "https":
		setupGitHTTPS(httpsToken)
	default:
		logWarning(fmt.Sprintf("Unknown git auth method: %s, defaulting to SSH", authMethod))
		setupGitSSH(sshKeyPath)
	}
}

func setupGitSSH(keyPath string) {
	// Check if SSH key exists
	if _, err := os.Stat(keyPath); os.IsNotExist(err) {
		logWarning(fmt.Sprintf("SSH key not found at %s, git operations may fail", keyPath))
		return
	}

	// Set GIT_SSH_COMMAND to use the specified SSH key
	// This tells git to use this key for all SSH operations
	sshCommand := fmt.Sprintf("ssh -i %s -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null", keyPath)
	if err := os.Setenv("GIT_SSH_COMMAND", sshCommand); err != nil {
		logWarning(fmt.Sprintf("failed to set GIT_SSH_COMMAND environment variable: %v", err))
		return
	}

	logInfo(fmt.Sprintf("Configured git to use SSH key: %s", keyPath))
}

func setupGitHTTPS(token string) {
	if token == "" {
		logWarning("GitHub personal access token not provided, git HTTPS operations may fail")
		return
	}

	// Configure git to use the token for HTTPS authentication
	// Format: https://<token>@github.com/<user>/<repo>.git
	// We use git credential helper to store the token
	if err := os.Setenv("GIT_ASKPASS", "true"); err != nil {
		logWarning(fmt.Sprintf("failed to set GIT_ASKPASS: %v", err))
	}

	// Create a temporary git credential helper script that provides the token
	credentialHelper := fmt.Sprintf("printf '%s'", token)
	if err := os.Setenv("GIT_ASKPASS_SUDO", credentialHelper); err != nil {
		logWarning(fmt.Sprintf("failed to set credential helper: %v", err))
		return
	}

	logInfo("Configured git to use HTTPS with personal access token")
}
