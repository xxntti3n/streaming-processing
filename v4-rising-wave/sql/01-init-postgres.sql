-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Customers table
CREATE TABLE IF NOT EXISTS customers (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name VARCHAR NOT NULL,
    email VARCHAR UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    customer_id BIGINT NOT NULL,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
);

-- Create indexes for better CDC performance
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_date ON orders(order_date);

-- ============================================================================
-- JDBC Sink Tables (CDC data will be written here by RisingWave)
-- ============================================================================

-- Customers sink table
CREATE TABLE IF NOT EXISTS customers_sink (
    id BIGINT PRIMARY KEY,
    name VARCHAR NOT NULL,
    email VARCHAR NOT NULL,
    created_at TIMESTAMP
);

-- Orders sink table
CREATE TABLE IF NOT EXISTS orders_sink (
    id BIGINT PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    order_date DATE NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR NOT NULL,
    created_at TIMESTAMP
);

-- Insert sample data
INSERT INTO customers (name, email) VALUES
    ('Alice Johnson', 'alice@example.com'),
    ('Bob Smith', 'bob@example.com'),
    ('Carol White', 'carol@example.com');

INSERT INTO orders (customer_id, order_date, amount, status) VALUES
    (1, '2025-01-15', 100.50, 'completed'),
    (2, '2025-01-16', 250.00, 'pending'),
    (1, '2025-01-17', 75.25, 'shipped');

-- Grant permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO postgres;
GRANT REPLICATION CLIENT TO postgres;