#!/bin/bash

read -p "Enter project name: " PROJECT_NAME
read -p "Enter database user: " DB_USER
read -p "Enter database password: " DB_PASSWORD

DB_NAME=$PROJECT_NAME

# Create Django project
django-admin startproject $PROJECT_NAME

# Change directory
cd $PROJECT_NAME || exit

# Create Python virtual environment
python3 -m venv venv

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

# Create Django apps
apps=("accounts" "billing" "products" "analytics" "support" "notifications" "admin" "content" "integrations" "security" "settings" "onboarding" "custom_features")

for app in "${apps[@]}"; do
    django-admin startapp $app

    # Create basic views.py
    cat <<EOL > $app/views.py
from django.shortcuts import render

def home(request):
    return render(request, '$app/home.html')
EOL

    # Create basic urls.py
    cat <<EOL > $app/urls.py
from django.urls import path
from . import views

app_name = '$app'
urlpatterns = [
    path('', views.home, name='home'),
]
EOL

    # Create templates directory for the app
    mkdir -p $app/templates/$app

    # Create a basic home.html template
    APP_NAME=$(echo $app | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    cat <<EOL > $app/templates/$app/home.html
{% extends "base.html" %}

{% block title %}${APP_NAME}{% endblock %}

{% block content %}
<h2>Welcome to ${APP_NAME}!</h2>
{% endblock %}
EOL
done

# Create static and templates directories
mkdir -p static/css
mkdir -p static/js
mkdir -p static/images
mkdir -p templates

# Add Bootstrap CSS and JS to static folder
curl -o static/css/bootstrap.min.css https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css
curl -o static/js/bootstrap.min.js https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/js/bootstrap.min.js

# Update the main urls.py file to include the apps
cat <<EOL > $PROJECT_NAME/urls.py
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
EOL

for app in "${apps[@]}"; do
    echo "    path('$app/', include('$app.urls'))," >> $PROJECT_NAME/urls.py
done

cat <<EOL >> $PROJECT_NAME/urls.py
]
EOL

# Update settings.py to include the templates and static directories
SETTINGS_FILE="$PROJECT_NAME/settings.py"

# Add TEMPLATES DIRS setting
sed -i "/TEMPLATES = \[/a \ \ \ \ 'DIRS': [os.path.join(BASE_DIR, 'templates')]," $SETTINGS_FILE

# Add STATICFILES DIRS setting
sed -i "/STATIC_URL = '\/static\/'/a \ \ \ \ STATICFILES_DIRS = [os.path.join(BASE_DIR, 'static')]" $SETTINGS_FILE

# Update base.html to include Bootstrap
cat <<EOL > templates/base.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}$PROJECT_NAME{% endblock %}</title>
    <link rel="stylesheet" href="{% static 'css/bootstrap.min.css' %}">
</head>
<body>
    <header>
        <nav class="navbar navbar-expand-lg navbar-light bg-light">
            <a class="navbar-brand" href="#">$PROJECT_NAME</a>
            <div class="collapse navbar-collapse">
                <ul class="navbar-nav">
                    <li class="nav-item"><a class="nav-link" href="/">Home</a></li>
                </ul>
            </div>
        </nav>
    </header>
    <main class="container mt-4">
        {% block content %}
        {% endblock %}
    </main>
    <footer class="bg-light py-3 mt-4">
        <div class="container text-center">
            <p>&copy; 2024 $PROJECT_NAME</p>
        </div>
    </footer>
    <script src="{% static 'js/bootstrap.min.js' %}"></script>
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

## Starting the Django Development Server
\`\`\`
python3 manage.py runserver
\`\`\`

## Creating New Django Apps
\`\`\`
python3 manage.py startapp <app_name>
\`\`\`

## Applying Migrations
\`\`\`
python3 manage.py makemigrations
python3 manage.py migrate
\`\`\`

## Creating Superuser
\`\`\`
python3 manage.py createsuperuser
\`\`\`

## Collecting Static Files
\`\`\`
python3 manage.py collectstatic
\`\`\`

## Running Tests
\`\`\`
python3 manage.py test
\`\`\`

## Database Details
- **Database Name**: $DB_NAME
- **Database User**: $DB_USER
- **Database Password**: $DB_PASSWORD

## Other Commands
- To build Docker images: \`docker-compose build\`
- To stop Docker: \`docker-compose down\`
\`\`\`
EOL

echo "Project setup complete!"