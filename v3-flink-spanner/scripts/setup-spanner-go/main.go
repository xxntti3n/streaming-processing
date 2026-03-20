// Simple Spanner setup program
// Run with: docker run --rm --network kind -v $(pwd):/app golang:1.24 go run /app/main.go
package main

import (
	"context"
	"fmt"
	"log"

	instanceadmin "cloud.google.com/go/spanner/admin/instance/apiv1"
	instancepb "cloud.google.com/go/spanner/admin/instance/apiv1/instancepb"
	databaseadmin "cloud.google.com/go/spanner/admin/database/apiv1"
	databasepb "cloud.google.com/go/spanner/admin/database/apiv1/databasepb"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func main() {
	ctx := context.Background()

	// Connect to emulator directly via gRPC
	conn, err := grpc.Dial("spanner-emulator:9010",
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithBlock(),
	)
	if err != nil {
		log.Fatalf("Failed to connect to emulator: %v", err)
	}
	defer conn.Close()

	fmt.Println("Connected to Spanner emulator!")

	// Create instance admin client with emulator connection
	instanceClient, err := instanceadmin.NewInstanceAdminClient(ctx, option.WithGRPCConn(conn))
	if err != nil {
		log.Printf("Warning: Could not create instance client: %v", err)
	} else {
		// Check if instance exists
		fmt.Println("\nChecking for instance...")
		iter := instanceClient.ListInstances(ctx, &instancepb.ListInstancesRequest{
			Parent: "projects/test-project",
		})

		found := false
		for {
			inst, err := iter.Next()
			if err == iterator.Done {
				break
			}
			if err != nil {
				break
			}
			fmt.Printf("Found instance: %s\n", inst.Name)
			found = true
		}

		if !found {
			fmt.Println("No instances found. Creating instance...")
			op, err := instanceClient.CreateInstance(ctx, &instancepb.CreateInstanceRequest{
				Parent:     "projects/test-project",
				InstanceId: "test-instance",
				Instance: &instancepb.Instance{
					Name:        "projects/test-project/instances/test-instance",
					DisplayName: "Test Instance",
					Config:      "projects/test-project/instanceConfigs/emulator-config",
					NodeCount:   1,
				},
			})
			if err != nil {
				fmt.Printf("CreateInstance error: %v\n", err)
			} else {
				fmt.Printf("Instance creation started: %s\n", op.Name())
			}
		}
	}

	// Create database admin client
	dbClient, err := databaseadmin.NewDatabaseAdminClient(ctx, option.WithGRPCConn(conn))
	if err != nil {
		log.Printf("Warning: Could not create database client: %v", err)
	} else {
		// List databases
		fmt.Println("\nChecking for databases...")
		iter := dbClient.ListDatabases(ctx, &databasepb.ListDatabasesRequest{
			Parent: "projects/test-project/instances/test-instance",
		})

		found := false
		for {
			db, err := iter.Next()
			if err == iterator.Done {
				break
			}
			if err != nil {
				// If instance doesn't exist, this will fail
				break
			}
			fmt.Printf("Found database: %s\n", db.Name)
			found = true
		}

		if !found {
			fmt.Println("No databases found. Creating database...")
			op, err := dbClient.CreateDatabase(ctx, &databasepb.CreateDatabaseRequest{
				Parent:          "projects/test-project/instances/test-instance",
				CreateStatement: "CREATE DATABASE ecommerce",
				ExtraStatements: []string{
					`CREATE TABLE customers (
						customer_id INT64 NOT NULL,
						email STRING(100),
						name STRING(100),
						created_at TIMESTAMP,
						updated_at TIMESTAMP
					) PRIMARY KEY (customer_id)`,
					`CREATE TABLE products (
						product_id INT64 NOT NULL,
						sku STRING(50),
						name STRING(200),
						price NUMERIC,
						category STRING(50),
						created_at TIMESTAMP
					) PRIMARY KEY (product_id)`,
					`CREATE TABLE orders (
						order_id INT64 NOT NULL,
						customer_id INT64 NOT NULL,
						product_id INT64 NOT NULL,
						quantity INT64 NOT NULL,
						total_amount NUMERIC,
						order_status STRING(20),
						created_at TIMESTAMP,
						updated_at TIMESTAMP,
						FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
						FOREIGN KEY (product_id) REFERENCES products(product_id)
					) PRIMARY KEY (order_id)`,
					`CREATE CHANGE STREAM ecommerce_change_stream
					FOR customers, products, orders
					OPTIONS (
						retention_period = "1h",
						capture_value_change_type = "NEW_ROW_AND_OLD_ROW"
					)`,
				},
			})
			if err != nil {
				fmt.Printf("CreateDatabase error: %v\n", err)
			} else {
				fmt.Printf("Database creation started: %s\n", op.Name())
			}
		}
	}

	fmt.Println("\nSetup complete!")
}
