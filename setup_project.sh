# setup_project.sh

#!/bin/bash

read -p "Enter project name: " PROJECT_NAME
read -p "Enter database name: " DB_NAME
read -p "Enter database user: " DB_USER
read -p "Enter database password: " DB_PASSWORD

# Create Django project
django-admin startproject $PROJECT_NAME

# Change directory
cd $PROJECT_NAME

# Create Python virtual environment
python -m venv venv

# Create requirements.txt file
echo "Django>=4.0,<5.0" > requirements.txt
echo "gunicorn" >> requirements.txt
echo "psycopg2-binary" >> requirements.txt

# Generate Docker files
cat <<EOL > Dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt

COPY . .

CMD ["gunicorn", "$PROJECT_NAME.wsgi:application", "--bind", "0.0.0.0:8000"]
EOL

cat <<EOL > docker-compose.yml
version: '3.8'

services:
  db:
    image: postgres:13
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: $DB_NAME
      POSTGRES_USER: $DB_USER
      POSTGRES_PASSWORD: $DB_PASSWORD

  web:
    build: .
    command: gunicorn $PROJECT_NAME.wsgi:application --bind 0.0.0.0:8000
    volumes:
      - .:/app
    ports:
      - "8000:8000"
    depends_on:
      - db

volumes:
  postgres_data:
EOL

# Create the templates directory and add sample components
mkdir -p $PROJECT_NAME/templates

cat <<EOL > $PROJECT_NAME/templates/header.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}$PROJECT_NAME{% endblock %}</title>
</head>
<body>
    <header>
        <h1>Welcome to $PROJECT_NAME</h1>
    </header>
EOL

cat <<EOL > $PROJECT_NAME/templates/footer.html
<footer>
    <p>&copy; 2024 $PROJECT_NAME</p>
</footer>
</body>
</html>
EOL

# Create commands.md
cat <<EOL > commands.md
# Commands for $PROJECT_NAME

## Setting up the environment
\`\`\`
source venv/bin/activate
\`\`\`

## Starting Docker
\`\`\`
docker-compose up
\`\`\`

## Database Details
- **Database Name**: $DB_NAME
- **Database User**: $DB_USER
- **Database Password**: $DB_PASSWORD

## Other commands
- To build Docker images: \`docker-compose build\`
- To stop Docker: \`docker-compose down\`
\`\`\`
EOL

echo "Project setup complete!"