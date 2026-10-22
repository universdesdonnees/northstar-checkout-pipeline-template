const body = document.body;
const ticketPrice = Number(body.dataset.ticketPrice);
const serviceFee = Number(body.dataset.serviceFee);

const quantityOutput = document.querySelector("#quantity");
const decreaseButton = document.querySelector("#decrease");
const increaseButton = document.querySelector("#increase");
const ticketLine = document.querySelector("#ticket-line");
const ticketTotal = document.querySelector("#ticket-total");
const feeTotal = document.querySelector("#fee-total");
const grandTotal = document.querySelector("#grand-total");
const checkoutForm = document.querySelector("#checkout-form");
const formStatus = document.querySelector("#form-status");

let quantity = 2;

function formatEuros(value) {
  return new Intl.NumberFormat("en-IE", {
    style: "currency",
    currency: "EUR",
  }).format(value);
}

function renderOrder() {
  const ticketSubtotal = quantity * ticketPrice;
  const fees = quantity * serviceFee;

  quantityOutput.value = quantity;
  quantityOutput.textContent = quantity;
  ticketLine.textContent = `${quantity} ${quantity === 1 ? "ticket" : "tickets"} × ${formatEuros(ticketPrice)}`;
  ticketTotal.textContent = formatEuros(ticketSubtotal);
  feeTotal.textContent = formatEuros(fees);
  grandTotal.textContent = formatEuros(ticketSubtotal + fees);
  decreaseButton.disabled = quantity === 1;
  increaseButton.disabled = quantity === 8;
}

decreaseButton.addEventListener("click", () => {
  quantity = Math.max(1, quantity - 1);
  renderOrder();
});

increaseButton.addEventListener("click", () => {
  quantity = Math.min(8, quantity + 1);
  renderOrder();
});

checkoutForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const submitButton = checkoutForm.querySelector("button[type='submit']");
  const email = new FormData(checkoutForm).get("email");

  submitButton.disabled = true;
  formStatus.className = "form-status";
  formStatus.textContent = "Creating your demo order…";

  try {
    const response = await fetch("/api/orders", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, quantity }),
    });
    const result = await response.json();

    if (!response.ok) {
      throw new Error(result.error || "The order could not be created.");
    }

    formStatus.className = "form-status success";
    formStatus.textContent = `${result.message} Reference ${result.order}.`;
  } catch (error) {
    formStatus.className = "form-status error";
    formStatus.textContent = error.message;
  } finally {
    submitButton.disabled = false;
  }
});

renderOrder();
