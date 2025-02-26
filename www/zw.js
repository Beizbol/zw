const rate_ms = 250

setInterval(async () => {
    const reply = await fetch("/zw");
    switch (reply.status) {
        case 204: // No Changes
            break;
        case 200: // OK Refresh
            document.location.reload(true);
            break;
        default:
            console.log("fetch error:", reply.status, reply.statusText)
            break;
    }
}, rate_ms)