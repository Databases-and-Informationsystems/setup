# Environment Setup for the annotation project

## Development
### Requirements
- [Docker](https://www.docker.com/products/docker-desktop/) installed

- Correct folder structure
```
├── annotation  (or any other root folder name)
│   ├── api
│   ├── frontend
│   ├── setup
  ```
### Create development setup

```shell
cd dev
```

```shell
docker compose build
```

### Run development setup
```shell
./run.sh dev
```
(It might be useful to create an `run` alias for `./run.sh)
- This runs all available database migrations that have not been executed jet
- Starts all necessary docker services

There are some options available (see `./run.sh --help`)
### Create new Database migration
```shell
./run.sh migrate
````
- This creates a new file in `./api/migrations/versions`, where all new changes to the database model are included.

## Production
TODO