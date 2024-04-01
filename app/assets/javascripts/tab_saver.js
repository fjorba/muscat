

function tab_saver_select() {
    if (!sessionStorage.getItem("tab-id")) {
        // We don't really need the full uuid
        sessionStorage.setItem("tab-id", this.crypto.randomUUID().substring(0, 8));
    }

    let tab_id = sessionStorage.getItem("tab-id");
    Cookies.set("tab-id", tab_id);
}

document.addEventListener("visibilitychange", function() {
    if (!document.hidden) {
        tab_saver_select();
    }
});

$(window).on('load', function() {
    tab_saver_select();
});