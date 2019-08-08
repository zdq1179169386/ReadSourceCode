# 阅读源码
[源码阅读](https://github.com/huang303513/SourceCodeResearchAndExploration)
### AFNetworking 
[AFNetworking到底做了什么](https://www.jianshu.com/p/856f0e26279d)
### SDWebimage
[马在路上的源码阅读系列](https://www.cnblogs.com/machao/category/832157.html)


### YYModel

1, class , ivar ,method ,property 都会做一层封装
2，缓存，YYModel 速度快的原因之一
3，尽量使用C 函数，
4，避免KVC 和 getter 和 setter 方法，使用底层api ， msg_send


###Aspects 
1，能在被hook 方法之前或之后执行，甚至能完全替代
2，hook 类方法的需要传入元类
3，被hook 的类 会生成前缀
4，会类 的 forwardInvocation 方法，从而统一处理
5， Aspects 的方案就是，对于待 hook 的 selector，将其指向 objc_msgForward / _objc_msgForward_stret ,同时生成一个新的 aliasSelector 指向原来的 IMP，并且 hook 住 forwardInvocation 函数，使他指向自己的实现。按照上面的思路，当被 hook 的 selector 被执行的时候，首先根据 selector 找到了 objc_msgForward / _objc_msgForward_stret ,而这个会触发消息转发，从而进入 forwardInvocation。同时由于 forwardInvocation 的指向也被修改了，因此会转入新的 forwardInvocation 函数，在里面执行需要嵌入的附加代码，完成之后，再转回原来的 IMP。
6，对于对象实例而言，源代码中并没有直接 swizzling 对象的 forwardInvocation 方法，而是动态生成一个当前对象的子类，并将当前对象与子类关联,然后替换子类的 forwardInvocation 方法(这里具体方法就是调用了 object_setClass(self, subclass) ,将当前对象 isa 指针指向了 subclass ,同时修改了 subclass 以及其 subclass metaclass 的 class 方法,使他返回当前对象的 class。,这个地方特别绕，它的原理有点类似 kvo 的实现，它想要实现的效果就是，将当前对象变成一个 subclass 的实例，同时对于外部使用者而言，又能把它继续当成原对象在使用，而且所有的 swizzling 操作都发生在子类，这样做的好处是你不需要去更改对象本身的类，也就是，当你在 remove aspects 的时候，如果发现当前对象的 aspect 都被移除了，那么，你可以将 isa 指针重新指回对象本身的类，从而消除了该对象的 swizzling ,同时也不会影响到其他该类的不同对象)。对于每一个对象而言，这样的动态对象只会生成一次，
