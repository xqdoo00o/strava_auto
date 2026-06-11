chrome.action.onClicked.addListener(() => {
    const appUrl = chrome.runtime.getURL("index.html");
    chrome.tabs.query({}, (tabs) => {
        const appTab = tabs.find((tab) => tab.url && tab.url.startsWith(appUrl));
        if (appTab?.id) {
            chrome.tabs.update(appTab.id, { active: true });
            if (appTab.windowId) {
                chrome.windows.update(appTab.windowId, { focused: true });
            }
            return;
        }
        chrome.tabs.create({ url: appUrl });
    });
});
