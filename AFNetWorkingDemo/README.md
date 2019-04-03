AFNetworking 源码梳理
一，
url => request => task => delegate

1，AFURLRequestSerialization : 将url 生成request ，包括请求头和请求参数的设置，参数的设置问题，递归调用
注意点：多表单请求的封装，multipartFormRequestWithMethod 方法， bodyStream ，boundary 的含义，

2，AFURLSessionManager： 会持有一个session ，用将request  生成 dataTask ，在创建dataTask 的时候，iOS8 会并发的创建dataTask ，从而造成dataTask id 不唯一，所以创建过程放在一个串行队列中异步执行的。

3，在管理多task 任务， 以及他们的回调问题上，新增了一个 AFURLSessionManagerTaskDelegate 类， 将 dataTask 和taskDelegate 一一对应起来。具体是根据taskID 为key ，task 作为 value 存放一个 字典（mutableTaskDelegatesKeyedByTaskIdentifier）中，在对字典的读写中，为防止多线程，使用了  NSLock 锁

4，AFURLSessionManager 在接受多task 的回调方法中，根据  task id 从 mutableTaskDelegatesKeyedByTaskIdentifier 字典取出 taskDelegate ，将回调转发到 taskDelegate 中取处理

5，taskDelegate 中会保留 与之对应的 task 的 服务器返回数据，下载进度，上传进度，请求回调的block

6，AFURLSessionManagerTaskDelegate 持有一个 弱引用的  AFURLSessionManager 是为了打破循环引用


二，
AFSecurityPolicy + https 流程，

三，
AFAutoPurgingImageCache ： 缓存图片的类
1， 内存缓存（字典缓存），+ 栅栏函书
2，NSURLCache ：
3，与SD 对比


HTTP : 
1，请求包括 请求行，请求头，请求体
2，get 请求和post 请求的区别：
get 是向服务器拿资源，post 是向服务器发送数据，
get 请求提交的数据不安全，参数会暴露在URL上

缺点 ：
1，通讯明文    =>  加密 
通讯加密：SSL
内容加密：MD5，Base64
2，不验证身份：
证书：
CA证书
自签证书

3，无法验证报文完整性

知识点：
1，keep-alive
2，管道化
3，无状态的
：针对无状态，加入 cookie 和 session
4，基于TCP 协议

HTTPS
主要：
https 流程
https://www.kuacg.com/22672.html



