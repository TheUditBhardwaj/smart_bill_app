

# 🚀 Smart Bill App

A comprehensive billing application with a **Flutter frontend** for a smooth user experience and a **FastAPI backend** for robust data management and bill generation. This application allows you to manage products, customers, and generate and send bills with ease, including PDF attachments via email\!

-----

## ✨ Features

### Backend (FastAPI)

  * **Product Management:** Add, view, update, and delete products from the inventory.
  * **Customer Management:** Add and view customer details.
  * **Bill Generation:** Create bills for customers with selected products and quantities.
  * **Inventory Integration:** Automatically updates product quantities upon bill generation.
  * **PDF Generation:** Generates professional-looking PDF invoices for each bill.
  * **Email Sending:** Sends generated invoices directly to customer emails with the PDF attached.
  * **SQLite Database:** Uses SQLite for simple and efficient data storage.

### Frontend (Flutter)

  * **Intuitive UI:** A clean and modern user interface built with Flutter's Material Design.
  * **Dashboard View:** Easily manage products and customer details.
  * **Create Bill View:** Select customers and products to generate a new bill.
  * **Real-time Updates:** Reflects inventory changes and bill additions instantly.
  * **Cross-Platform:** Being a Flutter app, it's designed to run on Android, iOS, Web, macOS, Windows, and Linux.

-----

## 🛠️ Technologies Used

### Backend

  * **FastAPI:** A modern, fast (high-performance) web framework for building APIs with Python 3.7+.
  * **Pydantic:** Used for data validation and settings management, integrated seamlessly with FastAPI.
  * **SQLite3:** Lightweight, file-based database.
  * **FPDF:** Python library for PDF document generation.
  * **smtplib & email.mime:** Python's standard library for sending emails.

### Frontend

  * **Flutter:** Google's UI toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase.
  * **`http` package:** For making HTTP requests to the FastAPI backend.

-----

## ⚙️ Setup and Installation

Follow these steps to get the Smart Bill App up and running on your local machine.

### Prerequisites

  * **Python 3.8+** (for the backend)
  * **Flutter SDK** (for the frontend)
  * **Git**

### 1\. Clone the Repository

```bash
git clone https://github.com/theuditbhardwaj/smart_bill_app.git
cd theuditbhardwaj-smart_bill_app
```

### 2\. Backend Setup

The backend handles API endpoints for products, customers, and bill processing.

```bash
cd backend
```

**Create a Virtual Environment (Recommended)**

```bash
python -m venv venv
# On Windows:
.\venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate
```

**Install Dependencies**

```bash
pip install -r requirements.txt
# If requirements.txt doesn't exist, create it with:
# pip freeze > requirements.txt
# Then manually add:
# fastapi
# uvicorn
# pydantic
# fpdf
# python-dotenv # Recommended for environment variables
```

**Environment Variables for Email (Optional but Recommended)**

For email functionality, it's highly recommended to use environment variables instead of hardcoding credentials in `main.py`. Create a `.env` file in the `backend/` directory:

```dotenv
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@example.com
SMTP_PASSWORD=your_app_specific_password # Use an App Password for Gmail!
```

**Important:** If you're using Gmail, you'll likely need to generate an **App Password** as traditional passwords are often blocked for security reasons when used with third-party apps. Refer to Google's documentation for "App passwords".

**Run the Backend Server**

```bash
uvicorn main:app --reload
```

The backend server will run on `http://127.0.0.1:8000`.

### 3\. Frontend Setup

The frontend is a Flutter application that interacts with the backend.

```bash
cd ../frontend
```

**Get Flutter Dependencies**

```bash
flutter pub get
```

**Run the Flutter Application**

Make sure your backend server is running.

```bash
flutter run
```

This will launch the Flutter application on your default configured device (e.g., Chrome for web, an Android emulator, or a desktop application).

-----

## 📝 Usage

Once both the backend and frontend are running:

  * **Dashboard:**

      * You can **add new products** to your inventory by filling out the product form.
      * You can **add new customers** with their details.
      * Existing products and customers will be listed, and you can **edit** or **delete** products.

  * **Create Bill:**

      * **Select a customer** from the dropdown.
      * **Search for products** and add them to the current bill by specifying the quantity. The app will check for available stock.
      * View the **bill preview** with individual item totals and the grand total.
      * Click "Generate & Send Bill" to create a PDF invoice, update inventory quantities in the backend, record the order, and **send the PDF invoice to the customer's email address**.

-----

## 🧪 Testing

### Backend Testing

You can test the backend API endpoints using tools like `curl`, Postman, or by running the provided `test.py` script:

```bash
# From the 'backend' directory
python test.py
```

**Note:** Ensure you replace the placeholder `customer` and `product` IDs in `test.py` with actual IDs from your `billing_app.db` if you want the test to interact with existing data.

-----

