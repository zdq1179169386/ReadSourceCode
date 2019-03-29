AFNetworking 源码梳理
url => request => task => delegate

1，AFURLRequestSerialization : 将url 生成request ，包括请求头和请求参数的设置，参数的设置问题，递归调用

2，AFURLSessionManager： 会持有一个session ，用将request  生成 dataTask ，在创建dataTask 的时候，iOS8 会并发的创建dataTask ，从而造成dataTask id 不唯一，所以创建过程放在一个串行队列中异步执行的。

3，在管理多task 任务， 以及他们的回调问题上，新增了一个 AFURLSessionManagerTaskDelegate 类， 将 dataTask 和taskDelegate 一一对应起来。具体是根据taskID 为key ，task 作为 value 存放一个 字典中，在对字典的读写中，为防止多线程，使用了  NSLock 锁

4，AFURLSessionManager 在接受多task 的回调方法中，根据  task id 从 mutableTaskDelegatesKeyedByTaskIdentifier 字典取出 taskDelegate ，将回调转发到 taskDelegate 中取处理

5，taskDelegate 中会保留 与之对应的 task 的 服务器返回数据，下载进度，上传进度，请求回调的block

6，AFURLSessionManagerTaskDelegate 持有一个 弱引用的  AFURLSessionManager 是为了打破循环引用
