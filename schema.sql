CREATE TABLE lists (
  id serial PRIMARY KEY,
  list_name varchar(100) UNIQUE NOT NULL
);

CREATE TABLE todos (
  id serial PRIMARY KEY,
  todo varchar(100) NOT NULL,
  completed boolean NOT NULL DEFAULT false,
  list_id int NOT NULL REFERENCES lists (id)
);