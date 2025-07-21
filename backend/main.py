# main.py
from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, ConfigDict
from typing import List, Dict, Any
import sqlite3
import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication
from fpdf import FPDF # For PDF generation
import datetime # For timestamping bills

# Initialize FastAPI app
app = FastAPI(
    title="Smart Billing App Backend",
    description="API for managing products, customers, and generating/sending bills."
)

# --- Database Setup ---
DATABASE_FILE = "billing_app.db"

def get_db_connection():
    """Establishes and returns a SQLite database connection."""
    conn = sqlite3.connect(DATABASE_FILE)
    conn.row_factory = sqlite3.Row # This allows accessing columns by name
    return conn

def create_tables():
    """Creates necessary database tables if they don't exist."""
    conn = get_db_connection()
    cursor = conn.cursor()

    # Products table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS products (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            quantity INTEGER NOT NULL
        )
    ''')

    # Customers table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS customers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT,
            email TEXT UNIQUE
        )
    ''')

    # Orders table (to track generated bills)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS orders (
            id TEXT PRIMARY KEY,
            customer_id TEXT NOT NULL,
            customer_name TEXT NOT NULL,
            customer_email TEXT NOT NULL,
            total_amount REAL NOT NULL,
            order_date TEXT NOT NULL,
            order_time TEXT NOT NULL,
            FOREIGN KEY (customer_id) REFERENCES customers(id)
        )
    ''')

    # Order_items table (details of products in each order)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS order_items (
            order_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            product_name TEXT NOT NULL,
            price_at_sale REAL NOT NULL,
            quantity INTEGER NOT NULL,
            PRIMARY KEY (order_id, product_id),
            FOREIGN KEY (order_id) REFERENCES orders(id),
            FOREIGN KEY (product_id) REFERENCES products(id)
        )
    ''')

    conn.commit()
    conn.close()

# Ensure tables are created on application startup
@app.on_event("startup")
async def startup_event():
    create_tables()
    print("Database tables checked/created successfully.")

# --- Pydantic Models for Request/Response Validation ---

class ProductBase(BaseModel):
    name: str
    price: float
    quantity: int

class ProductCreate(ProductBase):
    pass

class ProductInDB(ProductBase):
    id: str
    model_config = ConfigDict(from_attributes=True) # Updated for Pydantic V2

class CustomerBase(BaseModel):
    name: str
    phone: str
    email: str

class CustomerCreate(CustomerBase):
    pass

class CustomerInDB(CustomerBase):
    id: str
    model_config = ConfigDict(from_attributes=True) # Updated for Pydantic V2

class BillItem(BaseModel):
    id: str # Product ID
    name: str
    price: float
    billedQuantity: int

class BillData(BaseModel):
    customer: CustomerInDB
    items: List[BillItem]
    total: float
    date: str
    time: str

# --- Product Endpoints ---

@app.post("/products/", response_model=ProductInDB, status_code=status.HTTP_201_CREATED)
async def create_product(product: ProductCreate):
    conn = get_db_connection()
    cursor = conn.cursor()
    product_id = f"prod_{datetime.datetime.now().strftime('%Y%m%d%H%M%S%f')}"
    try:
        cursor.execute(
            "INSERT INTO products (id, name, price, quantity) VALUES (?, ?, ?, ?)",
            (product_id, product.name, product.price, product.quantity)
        )
        conn.commit()
        return {**product.dict(), "id": product_id}
    except sqlite3.IntegrityError as e:
        raise HTTPException(status_code=400, detail=f"Database error: {e}")
    finally:
        conn.close()

@app.get("/products/", response_model=List[ProductInDB])
async def get_products():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM products")
    products = cursor.fetchall()
    conn.close()
    # Explicitly convert sqlite3.Row objects to dictionaries
    return [dict(product) for product in products]

@app.get("/products/{product_id}", response_model=ProductInDB)
async def get_product(product_id: str):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM products WHERE id = ?", (product_id,))
    product = cursor.fetchone()
    conn.close()
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    return dict(product) # Explicitly convert to dictionary

@app.put("/products/{product_id}", response_model=ProductInDB)
async def update_product(product_id: str, product: ProductCreate):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE products SET name = ?, price = ?, quantity = ? WHERE id = ?",
        (product.name, product.price, product.quantity, product_id)
    )
    conn.commit()
    if cursor.rowcount == 0:
        conn.close()
        raise HTTPException(status_code=404, detail="Product not found")
    conn.close()
    return {**product.dict(), "id": product_id}

@app.delete("/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_product(product_id: str):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM products WHERE id = ?", (product_id,))
    conn.commit()
    if cursor.rowcount == 0:
        conn.close()
        raise HTTPException(status_code=404, detail="Product not found")
    conn.close()
    return

# --- Customer Endpoints ---

@app.post("/customers/", response_model=CustomerInDB, status_code=status.HTTP_201_CREATED)
async def create_customer(customer: CustomerCreate):
    conn = get_db_connection()
    cursor = conn.cursor()
    customer_id = f"cust_{datetime.datetime.now().strftime('%Y%m%d%H%M%S%f')}"
    try:
        cursor.execute(
            "INSERT INTO customers (id, name, phone, email) VALUES (?, ?, ?, ?)",
            (customer_id, customer.name, customer.phone, customer.email)
        )
        conn.commit()
        return {**customer.dict(), "id": customer_id}
    except sqlite3.IntegrityError as e:
        # This catches UNIQUE constraint violations, e.g., for email
        raise HTTPException(status_code=400, detail=f"Customer with this email already exists or another database error: {e}")
    finally:
        conn.close()

@app.get("/customers/", response_model=List[CustomerInDB])
async def get_customers():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM customers")
    customers = cursor.fetchall()
    conn.close()
    # Explicitly convert sqlite3.Row objects to dictionaries
    return [dict(customer) for customer in customers]

# --- Bill Generation and Email Sending Endpoint ---

# Configuration for email sending (replace with your actual details)
# It's highly recommended to use environment variables for these.
SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", 587))
SMTP_USERNAME = os.getenv("SMTP_USERNAME", "your_email@example.com") # Your sending email
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "your_email_password") # Your email password or app-specific password

def generate_bill_pdf(bill_data: BillData) -> bytes:
    """Generates a PDF bill from the provided bill data."""
    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Arial", size=12)

    # Pastel colors for PDF (example)
    pdf.set_fill_color(220, 230, 240) # Light Blue
    pdf.set_text_color(50, 50, 50) # Dark Gray

    # Header
    pdf.cell(200, 10, txt="Smart Billing App - Invoice", ln=True, align="C", fill=True)
    pdf.ln(10)

    # Shop Details (Placeholder)
    pdf.set_font("Arial", size=10)
    pdf.cell(0, 5, txt="Your Shop Name", ln=True)
    pdf.cell(0, 5, txt="123 Business St, City, Country", ln=True)
    pdf.cell(0, 5, txt="Phone: 123-456-7890 | Email: info@yourshop.com", ln=True)
    pdf.ln(10)

    # Customer Details
    pdf.set_font("Arial", 'B', size=12)
    pdf.cell(0, 7, txt="Bill To:", ln=True)
    pdf.set_font("Arial", size=10)
    pdf.cell(0, 5, txt=f"Name: {bill_data.customer.name}", ln=True)
    pdf.cell(0, 5, txt=f"Phone: {bill_data.customer.phone}", ln=True)
    pdf.cell(0, 5, txt=f"Email: {bill_data.customer.email}", ln=True)
    pdf.ln(10)

    # Bill Details
    pdf.cell(0, 5, txt=f"Invoice Date: {bill_data.date}", ln=True)
    pdf.cell(0, 5, txt=f"Invoice Time: {bill_data.time}", ln=True)
    pdf.ln(10)

    # Items Table Header
    pdf.set_font("Arial", 'B', size=10)
    pdf.set_fill_color(200, 210, 220) # Slightly darker blue for header
    pdf.cell(80, 8, "Item", 1, 0, 'C', 1)
    pdf.cell(30, 8, "Qty", 1, 0, 'C', 1)
    pdf.cell(40, 8, "Price", 1, 0, 'C', 1)
    pdf.cell(40, 8, "Total", 1, 1, 'C', 1)

    # Items Table Rows
    pdf.set_font("Arial", size=10)
    for item in bill_data.items:
        item_total = item.price * item.billedQuantity
        pdf.cell(80, 8, item.name, 1, 0)
        pdf.cell(30, 8, str(item.billedQuantity), 1, 0, 'C')
        pdf.cell(40, 8, f"${item.price:.2f}", 1, 0, 'R')
        pdf.cell(40, 8, f"${item_total:.2f}", 1, 1, 'R')

    pdf.ln(10)

    # Total
    pdf.set_font("Arial", 'B', size=12)
    pdf.cell(150, 10, "GRAND TOTAL:", 0, 0, 'R')
    pdf.cell(40, 10, f"${bill_data.total:.2f}", 1, 1, 'R', fill=True)

    pdf.ln(20)
    pdf.set_font("Arial", size=8)
    pdf.cell(0, 5, txt="Thank you for your business!", ln=True, align="C")

    return pdf.output(dest='S').encode('latin1') # Output as bytes

def send_email_with_attachment(recipient_email: str, subject: str, body: str, attachment_bytes: bytes, attachment_filename: str):
    """Sends an email with a PDF attachment."""
    msg = MIMEMultipart()
    msg['From'] = SMTP_USERNAME
    msg['To'] = recipient_email
    msg['Subject'] = subject

    msg.attach(MIMEText(body, 'plain'))

    # Attach PDF
    part = MIMEApplication(attachment_bytes, Name=attachment_filename)
    part['Content-Disposition'] = f'attachment; filename="{attachment_filename}"'
    msg.attach(part)

    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls() # Secure the connection
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.send_message(msg)
        print(f"Email sent successfully to {recipient_email}")
    except Exception as e:
        print(f"Failed to send email: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to send email: {e}")


@app.post("/generate-and-send-bill/", status_code=status.HTTP_200_OK)
async def generate_and_send_bill(bill_data: BillData):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # 1. Update Product Quantities in DB
        for item in bill_data.items:
            # First, get current quantity to ensure sufficient stock
            cursor.execute("SELECT quantity FROM products WHERE id = ?", (item.id,))
            current_quantity_row = cursor.fetchone()
            if current_quantity_row is None:
                conn.rollback()
                raise HTTPException(status_code=404, detail=f"Product with ID {item.id} not found.")
            current_quantity = current_quantity_row['quantity']

            if current_quantity < item.billedQuantity:
                conn.rollback()
                raise HTTPException(status_code=400, detail=f"Not enough quantity for product: {item.name}. Available: {current_quantity}")

            cursor.execute(
                "UPDATE products SET quantity = quantity - ? WHERE id = ?",
                (item.billedQuantity, item.id)
            )

        # 2. Record Order in DB
        order_id = f"order_{datetime.datetime.now().strftime('%Y%m%d%H%M%S%f')}"
        cursor.execute(
            "INSERT INTO orders (id, customer_id, customer_name, customer_email, total_amount, order_date, order_time) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (order_id, bill_data.customer.id, bill_data.customer.name, bill_data.customer.email,
             bill_data.total, bill_data.date, bill_data.time)
        )

        # 3. Record Order Items in DB
        for item in bill_data.items:
            cursor.execute(
                "INSERT INTO order_items (order_id, product_id, product_name, price_at_sale, quantity) VALUES (?, ?, ?, ?, ?)",
                (order_id, item.id, item.name, item.price, item.billedQuantity)
            )

        conn.commit()

        # 4. Generate PDF
        pdf_bytes = generate_bill_pdf(bill_data)
        pdf_filename = f"Invoice_{bill_data.customer.name.replace(' ', '_')}_{datetime.date.today().isoformat()}.pdf"

        # 5. Send Email
        # IMPORTANT: Replace SMTP_USERNAME and SMTP_PASSWORD with your actual email credentials
        # For Gmail, you might need to use an "App password" if 2FA is enabled.
        # Less secure app access needs to be enabled if 2FA is off (not recommended).
        send_email_with_attachment(
            recipient_email=bill_data.customer.email,
            subject=f"Your Purchase Receipt from Smart Billing App - Invoice #{order_id}",
            body="Dear Customer,\n\nThank you for your recent purchase from Smart Billing App. Please find your detailed invoice attached.\n\nWe appreciate your business!\n\nSincerely,\nYour Shop Team",
            attachment_bytes=pdf_bytes,
            attachment_filename=pdf_filename
        )

        return {"message": "Bill generated, inventory updated, order recorded, and email sent successfully!", "order_id": order_id}

    except HTTPException as e:
        conn.rollback() # Rollback changes if a specific HTTP error occurred
        raise e
    except Exception as e:
        conn.rollback() # Rollback all changes on any other error
        print(f"Error during bill processing: {e}")
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {e}")
    finally:
        conn.close()

