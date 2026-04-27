package grafana

import (
	"fmt"
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
		Host:    host,
		Schemes: []string{"http"},
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
