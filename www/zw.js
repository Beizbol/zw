
const ev_src = new EventSource("/zw");

ev_src.onerror = (err) => {
    console.error("eSrc err:", err);
};

ev_src.addEventListener("reload", () => {
    console.log("eSrc reload!");
    document.location.reload(true);
});

ev_src.addEventListener("nop", () => {
    console.log("eSrc nop!");
    // document.location.reload(true);
});

ev_src.onmessage = (event) => {
    console.warn("eSrc msg:", event)
};
