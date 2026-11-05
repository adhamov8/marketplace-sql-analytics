DROP TABLE IF EXISTS payments, order_items, orders, products, users CASCADE;

CREATE TABLE users (
  user_id INTEGER PRIMARY KEY,
  signup_date DATE NOT NULL,
  city TEXT NOT NULL,
  acquisition_channel TEXT NOT NULL
);

CREATE TABLE products (
  product_id INTEGER PRIMARY KEY,
  category TEXT NOT NULL,
  product_name TEXT NOT NULL,
  price NUMERIC(12,2) NOT NULL
);

CREATE TABLE orders (
  order_id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(user_id),
  order_date DATE NOT NULL,
  status TEXT NOT NULL
);

CREATE TABLE order_items (
  order_id INTEGER NOT NULL REFERENCES orders(order_id),
  product_id INTEGER NOT NULL REFERENCES products(product_id),
  quantity INTEGER NOT NULL,
  unit_price NUMERIC(12,2) NOT NULL,
  PRIMARY KEY (order_id, product_id)
);

CREATE TABLE payments (
  order_id INTEGER PRIMARY KEY REFERENCES orders(order_id),
  payment_method TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  payment_status TEXT NOT NULL
);
