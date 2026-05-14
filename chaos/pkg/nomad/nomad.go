package nomad

import (
	"fmt"

	"github.com/hashicorp/nomad/api"
)

type NomadClient struct {
	client *api.Client
}

func NewNomadClient(address string) (NomadClient, error) {
	config := &api.Config{
		Address: address,
	}
	client, err := api.NewClient(config)
	if err != nil {
		return NomadClient{}, fmt.Errorf("error creating client: %w", err)
	}

	return NomadClient{
		client: client,
	}, nil
}

func (c *NomadClient) GetJobAllocations(jobId string) ([]*api.AllocationListStub, error) {
	allocs, _, err := c.client.Jobs().Allocations(jobId, false, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get allocations for job %s: %w", jobId, err)
	}
	return allocs, nil
}

func (c *NomadClient) GetAllAllocations() ([]*api.AllocationListStub, error) {
	allocs, _, err := c.client.Allocations().List(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get allocations: %w", err)
	}
	return allocs, nil
}

func (c *NomadClient) StopAllocation(allocId string) error {
	alloc, _, err := c.client.Allocations().Info(allocId, nil)
	if err != nil {
		return fmt.Errorf("failed to get allocation %s: %w", allocId, err)
	}

	_, err = c.client.Allocations().Stop(alloc, nil)
	if err != nil {
		return fmt.Errorf("failed to stop allocation %v: %w", alloc.Name, err)
	}
	return nil
}
