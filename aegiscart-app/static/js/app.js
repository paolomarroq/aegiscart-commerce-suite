document.addEventListener("DOMContentLoaded", () => {
    const sidebar = document.querySelector("#sidebar");
    const sidebarToggle = document.querySelector("[data-toggle-sidebar]");

    if (sidebarToggle && sidebar) {
        sidebarToggle.addEventListener("click", () => {
            sidebar.classList.toggle("open");
        });
    }

    document.querySelectorAll(".alert").forEach((alert) => {
        window.setTimeout(() => {
            alert.style.opacity = "0";
            alert.style.transition = "opacity 180ms ease";
        }, 4200);
    });

    document.querySelectorAll("[data-order-detail]").forEach((button) => {
        button.addEventListener("click", () => {
            document.querySelectorAll("[data-order-detail]").forEach((item) => item.classList.remove("active"));
            button.classList.add("active");
        });
    });
});
