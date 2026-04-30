package grafana

import (
	"fmt"
	"net/url"
	"strings"

	grafanaClient "github.com/grafana/grafana-openapi-client-go/client"
	"github.com/grafana/grafana-openapi-client-go/models"
)

type Client struct {
	api *grafanaClient.GrafanaHTTPAPI
}

func NewClient(baseURL string) *Client {
	host := strings.TrimPrefix(strings.TrimPrefix(baseURL, "https://"), "http://")
	cfg := &grafanaClient.TransportConfig{
		Host:      host,
		BasePath:  "/api",
		Schemes:   []string{"http"},
		BasicAuth: url.UserPassword("admin", "admin"), //TODO: make configurable in the future or something
	}
	return &Client{
		api: grafanaClient.NewHTTPClientWithConfig(nil, cfg),
	}
}

func (c *Client) Annotate(text string, tags []string) error {
	body := &models.PostAnnotationsCmd{
		Text: &text,
		Tags: tags,
	}
	_, err := c.api.Annotations.PostAnnotation(body)
	if err != nil {
		return fmt.Errorf("posting annotation: %w", err)
	}

	return nil
}

func (c *Client) StartExperiment(name string) error {
	err := c.Annotate("experiment started", []string{"chaos", name})
	if err != nil {
		return err
	}
	return nil
}

func (c *Client) EndExperiment(name string) error {
	err := c.Annotate("experiment ended", []string{"chaos", name})
	if err != nil {
		return err
	}
	return nil
}
