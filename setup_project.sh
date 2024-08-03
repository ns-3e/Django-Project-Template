#!/bin/bash

# Prompt for user input
read -p "Enter project name: " PROJECT_NAME
# read -p "Enter database user: " DB_USER
# read -p "Enter database password: " DB_PASSWORD
DB_NAME=$PROJECT_NAME
DB_USER=postgres
DB_PASSWORD=postgres

# if project directory exists, delete it
if [ -d "$PROJECT_NAME" ]; then
    rm -rf $PROJECT_NAME
fi

# Create Django project
django-admin startproject $PROJECT_NAME

# Change directory
cd $PROJECT_NAME || exit

# Create Python virtual environment
python3 -m venv venv

# Activate the virtual environment
source venv/bin/activate

# Create requirements.txt file
cat <<EOL > requirements.txt
Django>=4.0,<5.0
gunicorn
psycopg2-binary
Pillow
EOL

# Install required packages
pip install -r requirements.txt

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

# Brew install postgresql
brew install postgresql

# Start postgresql
brew services start postgresql

# Create Local DB 
createdb $DB_NAME -U $DB_USER

# Create Django apps
apps=("accounts" "billing" "products" "analytics" "support" "notifications" "content" "integrations" "security" "settings_app" "onboarding" "custom_features")

# Create templates directory
mkdir -p templates

# add include to urls.py
sed -i '' "/from django.urls import path/a\\
from django.urls import path, include
" $PROJECT_NAME/urls.py


# Loop to create apps and generate files
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
    mkdir -p templates/$app
    
    # Capitalize the app name for the home.html file
    capitalized_app=$(echo "$app" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    
    # Create a basic home.html template
    cat <<EOL > templates/$app/home.html
{% extends "base.html" %}

{% block title %}$capitalized_app{% endblock %}

{% block content %}
<h2>Welcome to $capitalized_app!</h2>
{% endblock %}
EOL

    # Create models.py for each app with specified models
    case $app in
        "accounts")
            cat <<EOL > $app/models.py
from django.db import models
from django.contrib.auth.models import AbstractUser

class User(AbstractUser):
    phone_number = models.CharField(max_length=15, blank=True, null=True)
    profile_picture = models.ImageField(upload_to='profiles/', blank=True, null=True)
    date_of_birth = models.DateField(blank=True, null=True)
    groups = models.ManyToManyField(
        'auth.Group',
        related_name='accounts_users',
        blank=True,
        help_text='The groups this user belongs to. A user will get all permissions granted to each of their groups.',
        verbose_name='groups',
    )
    user_permissions = models.ManyToManyField(
        'auth.Permission',
        related_name='accounts_users_permissions',
        blank=True,
        help_text='Specific permissions for this user.',
        verbose_name='user permissions',
    )

    def __str__(self):
        return self.username

class Address(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='addresses')
    street_address = models.CharField(max_length=255)
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    postal_code = models.CharField(max_length=20)
    country = models.CharField(max_length=100)

    def __str__(self):
        return f"{self.street_address}, {self.city}, {self.state}, {self.postal_code}, {self.country}"
EOL
            ;;
        "billing")
            cat <<EOL > $app/models.py
from django.db import models
from django.conf import settings

class Invoice(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)
    due_date = models.DateField()
    total_amount = models.DecimalField(max_digits=10, decimal_places=2)
    is_paid = models.BooleanField(default=False)

    def __str__(self):
        return f"Invoice #{self.id} for {self.user.username}"

class Payment(models.Model):
    invoice = models.ForeignKey(Invoice, on_delete=models.CASCADE)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    payment_date = models.DateTimeField(auto_now_add=True)
    payment_method = models.CharField(max_length=50)

    def __str__(self):
        return f"Payment of {self.amount} for Invoice #{self.invoice.id}"
EOL
            ;;
        "products")
            cat <<EOL > $app/models.py
from django.db import models

class Category(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True, null=True)

    def __str__(self):
        return self.name

class Product(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    category = models.ForeignKey(Category, on_delete=models.CASCADE, related_name='products')
    stock_quantity = models.PositiveIntegerField()

    def __str__(self):
        return self.name
EOL
            ;;
        "analytics")
            cat <<EOL > $app/models.py
from django.db import models
from django.conf import settings

class UserActivity(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    activity_type = models.CharField(max_length=50)
    description = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.activity_type} by {self.user.username} at {self.timestamp}"
EOL
            ;;
        "support")
            cat <<EOL > $app/models.py
from django.db import models
from django.conf import settings

class Ticket(models.Model):
    STATUS_CHOICES = [
        ('open', 'Open'),
        ('in_progress', 'In Progress'),
        ('closed', 'Closed'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    subject = models.CharField(max_length=255)
    description = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='open')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Ticket #{self.id} - {self.subject}"
EOL
            ;;
        "notifications")
            cat <<EOL > $app/models.py
from django.db import models
from django.conf import settings

class Notification(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Notification for {self.user.username} at {self.created_at}"
EOL
            ;;
        "content")
            cat <<EOL > $app/models.py
from django.db import models

class Article(models.Model):
    title = models.CharField(max_length=255)
    body = models.TextField()
    published_at = models.DateTimeField(auto_now_add=True)
    is_published = models.BooleanField(default=False)

    def __str__(self):
        return self.title

class Comment(models.Model):
    article = models.ForeignKey(Article, on_delete=models.CASCADE, related_name='comments')
    author_name = models.CharField(max_length=100)
    body = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Comment by {self.author_name} on {self.article.title}"
EOL
            ;;
        "integrations")
            cat <<EOL > $app/models.py
from django.db import models

class Integration(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    configuration = models.JSONField()  # Store configuration as JSON

    def __str__(self):
        return self.name
EOL
            ;;
        "security")
            cat <<EOL > $app/models.py
from django.db import models
from django.conf import settings

class SecurityLog(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    action = models.CharField(max_length=255)
    details = models.TextField(blank=True, null=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.action} by {self.user.username} at {self.timestamp}"
EOL
            ;;
        "settings_app")
            cat <<EOL > $app/models.py
from django.db import models
from django.conf import settings

class SiteSetting(models.Model):
    key = models.CharField(max_length=100)
    value = models.CharField(max_length=255)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, null=True, blank=True)

    def __str__(self):
        return f"{self.key}: {self.value}"
EOL
            ;;
        "onboarding")
            cat <<EOL > $app/models.py
from django.db import models
from django.conf import settings

class OnboardingStep(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    step_name = models.CharField(max_length=255)
    completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Step {self.step_name} for {self.user.username}"
EOL
            ;;
        "custom_features")
            cat <<EOL > $app/models.py
from django.db import models

class CustomFeature(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name
EOL
            ;;
        *)
            echo "No models created for $app"
            ;;
    esac

    # Add the app to the INSTALLED_APPS in settings.py
    sed -i '' "/INSTALLED_APPS = \[/a\\
    '$app',
    " $PROJECT_NAME/settings.py

    # Add the app's urls to the main urls.py
    sed -i '' "/urlpatterns = \[/a\\
    path('$app/', include('$app.urls')),
    " $PROJECT_NAME/urls.py
done

# Create static and templates directories
mkdir -p static/css
mkdir -p static/js
mkdir -p static/images

# Create base.html for templates
cat <<EOL > templates/base.html
<!DOCTYPE html>
<html lang="en">
  <head>
      <meta charset="UTF-8">
      <meta http-equiv="X-UA-Compatible" content="IE=edge">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>{% block title %}{{ title }}{% endblock %}</title>
  </head>
  <body>
      <header>
          <nav>
              <ul>
                  <li><a href="{% url 'home' %}">Home</a></li>
                  <li><a href="{% url 'about' %}">About</a></li>
                  <li><a href="{% url 'contact' %}">Contact</a></li>
              </ul>
          </nav>
      </header>
      <main>
          {% block content %}
          {% endblock %}
      </main>
      <footer>
          <p>&copy; 2024 $PROJECT_NAME</p>
      </footer>
  </body>
</html>
EOL

# Remove existing settings if they exist
sed -i '' "/^STATIC_URL =/d" $PROJECT_NAME/settings.py
sed -i '' "/^STATICFILES_DIRS =/d" $PROJECT_NAME/settings.py
sed -i '' "/^MEDIA_URL =/d" $PROJECT_NAME/settings.py
sed -i '' "/^MEDIA_ROOT =/d" $PROJECT_NAME/settings.py
sed -i '' "/^DEFAULT_AUTO_FIELD =/d" $PROJECT_NAME/settings.py
sed -i '' '/^DATABASES = {/,/^}/d' $PROJECT_NAME/settings.py
sed -i '' "/^AUTH_USER_MODEL =/d" $PROJECT_NAME/settings.py
sed -i '' "/^AUTHENTICATION_BACKENDS =/d" $PROJECT_NAME/settings.py
sed -i '' "/^LOGIN_REDIRECT_URL =/d" $PROJECT_NAME/settings.py
sed -i '' "/^LOGOUT_REDIRECT_URL =/d" $PROJECT_NAME/settings.py
sed -i '' "/^LANGUAGE_CODE =/d" $PROJECT_NAME/settings.py
sed -i '' "/^TIME_ZONE =/d" $PROJECT_NAME/settings.py
sed -i '' "/^USE_I18N =/d" $PROJECT_NAME/settings.py
sed -i '' "/^USE_L10N =/d" $PROJECT_NAME/settings.py
sed -i '' "/^USE_TZ =/d" $PROJECT_NAME/settings.py

# Append the new settings
cat <<EOL >> $PROJECT_NAME/settings.py

STATIC_URL = '/static/'
STATICFILES_DIRS = [BASE_DIR / 'static']

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': '$DB_NAME',
        'USER': '$DB_USER',
        'PASSWORD': '$DB_PASSWORD',
        # 'HOST': 'DB',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

AUTH_USER_MODEL = 'accounts.User'

AUTHENTICATION_BACKENDS = [
    'django.contrib.auth.backends.ModelBackend',
]

LOGIN_REDIRECT_URL = '/'
LOGOUT_REDIRECT_URL = '/'

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_L10N = True
USE_TZ = True
EOL

# Add BASE_DIR / 'templates' to DIRS in TEMPLATES
sed -i '' "/'DIRS': \[\]/c\
                'DIRS': [BASE_DIR / 'templates'],
" $PROJECT_NAME/settings.py

# Apply migrations
source venv/bin/activate
pip install -r requirements.txt
python3 manage.py makemigrations
python3 manage.py migrate

echo "Setup complete. Don't forget to create a superuser and run the server!"