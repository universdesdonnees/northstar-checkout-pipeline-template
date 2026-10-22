import os
import secrets
import socket

from flask import Flask, jsonify, render_template, request

app = Flask(__name__)

SERVICE_NAME = "northstar-checkout"
APP_VERSION = os.environ.get("APP_VERSION", "dev")
TICKET_PRICE_CENTS = 4800
SERVICE_FEE_CENTS = 350


def runtime_info():
    return {
        "service": SERVICE_NAME,
        "version": APP_VERSION,
        "environment": os.environ.get("NORTHSTAR_ENVIRONMENT", "not set"),
        "host": socket.gethostname(),
    }


@app.get("/")
def home():
    return render_template(
        "index.html",
        runtime=runtime_info(),
        ticket_price=TICKET_PRICE_CENTS / 100,
        service_fee=SERVICE_FEE_CENTS / 100,
    )


@app.get("/health")
def health():
    return jsonify(status="healthy", **runtime_info()), 200


@app.get("/api/info")
def info():
    return jsonify(**runtime_info()), 200


@app.post("/api/orders")
def create_demo_order():
    payload = request.get_json(silent=True) or {}
    quantity = payload.get("quantity")
    email = str(payload.get("email", "")).strip()

    if type(quantity) is not int or not 1 <= quantity <= 8:
        return jsonify(error="Choose between 1 and 8 tickets."), 400

    if "@" not in email or email.startswith("@") or email.endswith("@"):
        return jsonify(error="Enter a valid email address."), 400

    total_cents = quantity * (TICKET_PRICE_CENTS + SERVICE_FEE_CENTS)

    return (
        jsonify(
            message="Demo order confirmed. No payment was taken.",
            order=f"NS-{secrets.token_hex(3).upper()}",
            quantity=quantity,
            total=f"€{total_cents / 100:.2f}",
        ),
        201,
    )


@app.after_request
def add_response_headers(response):
    response.headers["X-Northstar-Version"] = APP_VERSION
    return response


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
