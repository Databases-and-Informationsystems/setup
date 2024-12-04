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
│   ├── pipeline
│   ├── difference-calc
  ```

### Run development setup
```shell
cd dev
```
```shell
./run.sh dev
```
(It might be useful to create an `run` alias for `./run.sh)
- This runs all available database migrations that have not been executed jet
- Starts all necessary docker services

There are some options available (see `./run.sh --help`)
In case the terminal closes directly with the --help flag on Windows, the options are additionally listed here:
- Options:
  - `./run.sh dev [-s|--skip] [-v|--verbose] [-d|--delete]`
  - `./run.sh migrate [-v|--verbose]"`
- Commands:
  - `dev`: Starts the stack in development mode
  - `migrate`: Creates Flask migrations
- Options:
  - `-s`, `--skip`: Skip the database upgrade in dev mode
  - `-v`, `--verbose`: Run in verbose mode (stream all input/output to terminal)
  - `-d`, `--delete`: Delete the volume annotation_data before starting
  - `-h`, `--help`: Show this help message

#### Access the services
The backend can be accessed via `localhost/api`

The frontend can be accessed via `localhost`

### Create new Database migration
```shell
./run.sh migrate
````
- This creates a new file in `./api/migrations/versions`, where all new changes to the database model are included.

## Production
TODO