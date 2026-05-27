CREATE DATABASE IF NOT EXISTS aegiscart CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(160) NOT NULL,
    description VARCHAR(500) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(160) NOT NULL DEFAULT 'Operador Aegis',
    customer_email VARCHAR(180) NOT NULL DEFAULT 'operator@aegiscart.local',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    total DECIMAL(10,2) NOT NULL DEFAULT 0,
    failure_reason VARCHAR(500) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO products (name, description, price, stock, status)
SELECT 'Aegis Keyboard K1', 'Teclado mecanico para estaciones de soporte.', 79.99, 12, 'active'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name='Aegis Keyboard K1');

INSERT INTO products (name, description, price, stock, status)
SELECT 'Aegis Mouse M2', 'Mouse de precision para operadores e-commerce.', 39.50, 18, 'active'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name='Aegis Mouse M2');

INSERT INTO products (name, description, price, stock, status)
SELECT 'Operations Monitor 27', 'Monitor QHD para tableros de control.', 249.00, 7, 'active'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name='Operations Monitor 27');

INSERT INTO products (name, description, price, stock, status)
SELECT 'NVMe Catalog Cache 1TB', 'SSD para catalogos y busquedas rapidas.', 94.75, 10, 'active'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name='NVMe Catalog Cache 1TB');
