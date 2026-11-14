// Push only, no offline cache. Notifications::Channels::WebPush sends
// { title, body, url, tag }; tapping one focuses or opens that URL.
self.addEventListener("push", (event) => {
  const data = event.data ? event.data.json() : {}
  event.waitUntil(
    self.registration.showNotification(data.title || "", {
      body: data.body || "",
      icon: "/icon.png",
      tag: data.tag,
      data: { url: data.url || "/" }
    })
  )
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const url = event.notification.data && event.notification.data.url
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((windows) => {
      const open = windows.find((client) => client.url === url && "focus" in client)
      if (open) return open.focus()
      if (clients.openWindow) return clients.openWindow(url || "/")
    })
  )
})
