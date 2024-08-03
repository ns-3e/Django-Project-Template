# Django-Project-Template
```chmod +x setup_project.sh```
```./setup_project.sh```

# Registering Apps in `INSTALLED_APPS`

To register all these apps in your `settings.py` file, add them to the `INSTALLED_APPS` list like so:

```python
INSTALLED_APPS = [
    .....
    'accounts',
    'billing',
    'products',
    'analytics',
    'support',
    'notifications',
    'admin',
    'content',
    'integrations',
    'security',
    'settings',
    'onboarding',
    'custom_features',
]
```

This ensures that Django knows about all the installed apps and can handle their models, views, and other components properly.

# Update Models

### 1. **Accounts**

**`accounts/models.py`**
```python
from django.db import models
from django.contrib.auth.models import AbstractUser

class User(AbstractUser):
    phone_number = models.CharField(max_length=15, blank=True, null=True)
    profile_picture = models.ImageField(upload_to='profiles/', blank=True, null=True)
    date_of_birth = models.DateField(blank=True, null=True)

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
```

### 2. **Billing**

**`billing/models.py`**
```python
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
```

### 3. **Products**

**`products/models.py`**
```python
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
```

### 4. **Analytics**

**`analytics/models.py`**
```python
from django.db import models
from django.conf import settings

class UserActivity(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    activity_type = models.CharField(max_length=50)
    description = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.activity_type} by {self.user.username} at {self.timestamp}"
```

### 5. **Support**

**`support/models.py`**
```python
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
```

### 6. **Notifications**

**`notifications/models.py`**
```python
from django.db import models
from django.conf import settings

class Notification(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Notification for {self.user.username} at {self.created_at}"
```

### 7. **Admin**

**`admin/models.py`**
```python
# Typically, this app would not require models unless you want to extend Django's admin functionality.
# For example, if you want to create custom admin configurations.

from django.db import models
from django.contrib.auth.models import Group

class AdminActivity(models.Model):
    admin = models.ForeignKey(Group, on_delete=models.CASCADE)  # Adjust this as needed
    action = models.CharField(max_length=255)
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.action} by {self.admin.name} at {self.timestamp}"
```

### 8. **Content**

**`content/models.py`**
```python
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
```

### 9. **Integrations**

**`integrations/models.py`**
```python
from django.db import models

class Integration(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    configuration = models.JSONField()  # Store configuration as JSON

    def __str__(self):
        return self.name
```

### 10. **Security**

**`security/models.py`**
```python
from django.db import models
from django.conf import settings

class SecurityLog(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    action = models.CharField(max_length=255)
    details = models.TextField(blank=True, null=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.action} by {self.user.username} at {self.timestamp}"
```

### 11. **Settings**

**`settings/models.py`**
```python
from django.db import models
from django.conf import settings

class SiteSetting(models.Model):
    key = models.CharField(max_length=100)
    value = models.CharField(max_length=255)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, null=True, blank=True)

    def __str__(self):
        return f"{self.key}: {self.value}"
```

### 12. **Onboarding**

**`onboarding/models.py`**
```python
from django.db import models
from django.conf import settings

class OnboardingStep(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    step_name = models.CharField(max_length=255)
    completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Step {self.step_name} for {self.user.username}"
```

### 13. **Custom Features**

**`custom_features/models.py`**
```python
from django.db import models

class CustomFeature(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name
```

