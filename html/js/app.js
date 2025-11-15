const ui = document.getElementById("inspection-ui");
const historyUI = document.getElementById("history-ui");

window.addEventListener("message", (event) => {
    if (event.data.action === "openUI") {
        document.getElementById("plateTxt").textContent = event.data.plate;
        document.getElementById("engineTxt").textContent = event.data.engine;
        document.getElementById("bodyTxt").textContent = event.data.body;
        document.getElementById("tyresTxt").textContent = event.data.burstTyres;
        document.getElementById("windowsTxt").textContent = event.data.missingWindows;

        ui.classList.remove("hidden");
    }

    if (event.data.action === "closeUI") {
        ui.classList.add("hidden");
    }

    if (event.data.action === "openHistory") {
        loadHistory(event.data.history, event.data.plate);
    }
});

function submitInspection(passed) {
    const result = {
        passed: passed,
        checks: {
            plate: document.getElementById("plateTxt").textContent,
            engine: Number(document.getElementById("engineTxt").textContent),
            body: Number(document.getElementById("bodyTxt").textContent),
            burstTyres: Number(document.getElementById("tyresTxt").textContent),
            missingWindows: Number(document.getElementById("windowsTxt").textContent)
        }
    };

    fetch(`https://${GetParentResourceName()}/inspectionResult`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(result)
    });

    ui.classList.add("hidden");
}

function loadHistory(data, plate) {
    historyUI.classList.remove("hidden");
    const hist = document.getElementById("history-content");
    hist.innerHTML = `<h3>Plate: ${plate}</h3>`;

    data.forEach(row => {
        const status = row.passed == 1 ? "history-pass" : "history-fail";
        const expired = row.expires_at && row.expired ? "history-expired" : "";

        hist.innerHTML += `
            <div class="history-row">
                <b class="${status}">${row.passed == 1 ? "PASSED" : "FAILED"}</b>
                ${expired ? `<span class="${expired}"> (EXPIRED)</span>` : ""}
                <br>
                <span>Inspector: ${row.name}</span><br>
                <span>Date: ${row.created_at}</span>
            </div>
        `;
    });
}

function closeHistory() {
    historyUI.classList.add("hidden");
    fetch(`https://${GetParentResourceName()}/close`, { method: "POST" });
}

document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
        closeHistory();
        ui.classList.add("hidden");
    }
});
