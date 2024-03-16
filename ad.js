// Loon 广告拦截 404 插件

(function() {
  // 创建广告域名和 IP 地址列表
  const adDomains = [
    "example.com",
    "example2.com",
    "example3.com",
  ];
  const adIps = [
    "1.1.1.1",
    "2.2.2.2",
    "3.3.3.3",
  ];

  // 拦截 Loon 中的网络请求
  Loon.addNetworkInterceptor({
    beforeSendRequest: function(request) {
      // 检查请求是否来自广告域名或 IP 地址
      if (adDomains.includes(request.url) || adIps.includes(request.host)) {
        // 返回 404 状态码
        request.respond({
          status: 404,
          body: "Not Found",
        });
      }
    },
  });
})();
