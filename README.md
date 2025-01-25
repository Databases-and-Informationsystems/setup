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
  - `./run.sh restore create <name>`
  - `./run.sh restore`
  - `./run.sh test`
- Commands:
  - `dev`: Starts the stack in development mode
  - `migrate`: Creates Flask migrations
  - `restore`: Manages database volumes
  - `test`: runs (unit)tests
- Options:
  - `-s`, `--skip`: Skip the database upgrade in dev mode
  - `-v`, `--verbose`: Run in verbose mode (stream all input/output to terminal)
  - `-d`, `--delete`: Delete the volume annotation_data before starting
  - `-h`, `--help`: Show this help message

#### Access the services
- The **frontend** can be accessed via [localhost](http://localhost)
- The **backend** (api project) can be accessed via [localhost/api](http://localhost/api)
- The **backend api doc** can be accessed via [localhost:5001/api/docs](http://localhost:5001/api/docs)
- The **pipeline** can be accessed via [localhost/pipeline](http://localhost/pipeline)
- The **pipeline api doc** can be accessed via [localhost:8080/pipeline/docs](http://localhost:8080/pipeline/docs)
- The **difference calculator** can be accessed via [localhost/difference-calc](http://localhost/difference-calc)
- The **difference calculator api doc** can be accessed via [localhost:8443/difference-calc/docs](http://localhost:8443/difference-calc/docs)

### Create new Database migration
```shell
./run.sh migrate
````
- This creates a new file in `./api/migrations/versions`, where all new changes to the database model are included.
- **Important**: Before pushing the new migration, it should be tested at least with an empty database (`./run.sh dev -d`)

### Work with different database states
When working on different branches with different migrations, or modifying the data to possible invalid database states during development, is it helpful and useful to be able to save and restore a state of the database.

#### Cloning the current database state
```shell
./run.sh restore create <name>
```
- this creates a new restore point with the current content of the database
- it can be identified by its custom name, so that the restore point can be used in a later time

#### Using a created restore point
```shell
./run.sh restore
```

- this lists all available restore point
- when selecting a restore point by its number, it replaces the current state of the database
  - Warning: This will overwrite the currently used database

#### reload the database from scratch
```shell
./run.sh dev -d
```
- this deletes the database, and creates a new, empty database by applying all migrations

## Production
TODO