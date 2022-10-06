# 预备知识-Android C++ 层基石 BaseRef wp sp

## 引子

Android系统的运行时库层代码是用C++来编写的，用C++来写代码最容易出错的地方就是指针了，一旦使用不当，轻则造成内存泄漏，重则造成系统崩溃。不过系统为我们提供了智能指针，避免出现上述问题，本文将系统地分析Android系统智能指针（轻量级指针、强指针和弱指针）的实现原理。

在使用C++来编写代码的过程中，指针使用不当造成内存泄漏一般就是因为new了一个对象并且使用完之后，忘记了delete这个对象，而造成系统崩溃一般就是因为一个地方delete了这个对象之后，其它地方还在继续使原来指向这个对象的指针。为了避免出现上述问题，一般的做法就是使用引用计数的方法，每当有一个指针指向了一个new出来的对象时，就对这个对象的引用计数增加1，每当有一个指针不再使用这个对象时，就对这个对象的引用计数减少1，每次减1之后，如果发现引用计数值为0时，那么，就要delete这个对象了，这样就避免了忘记delete对象或者这个对象被delete之后其它地方还在使用的问题了。但是，如何实现这个对象的引用计数呢？肯定不是由开发人员来手动地维护了，要开发人员时刻记住什么时候该对这个对象的引用计数加1，什么时候该对这个对象的引用计数减1，一来是不方便开发，二来是不可靠，一不小心哪里多加了一个1或者多减了一个1，就会造成灾难性的后果。这时候，智能指针就粉墨登场了。首先，智能指针是一个对象，不过这个对象代表的是另外一个真实使用的对象，当智能指针指向实际对象的时候，就是智能指针对象创建的时候，当智能指针不再指向实际对象的时候，就是智能指针对象销毁的时候，我们知道，在C++中，对象的创建和销毁时会分别自动地调用对象的构造函数和析构函数，这样，负责对真实对象的引用计数加1和减1的工作就落实到智能指针对象的构造函数和析构函数的身上了，这也是为什么称这个指针对象为智能指针的原因。

在计算机科学领域中，提供垃圾收集（Garbage Collection）功能的系统框架，即提供对象托管功能的系统框架，例如Java应用程序框架，也是采用上述的引用计数技术方案来实现的，然而，简单的引用计数技术不能处理系统中对象间循环引用的情况。考虑这样的一个场景，系统中有两个对象A和B，在对象A的内部引用了对象B，而在对象B的内部也引用了对象A。当两个对象A和B都不再使用时，垃圾收集系统会发现无法回收这两个对象的所占据的内存的，因为系统一次只能收集一个对象，而无论系统决定要收回对象A还是要收回对象B时，都会发现这个对象被其它的对象所引用，因而就都回收不了，这样就造成了内存泄漏。这样，就要采取另外的一种引用计数技术了，即对象的引用计数同时存在强引用和弱引用两种计数，例如，Apple公司提出的Cocoa框架，当父对象要引用子对象时，就对子对象使用强引用计数技术，而当子对象要引用父对象时，就对父对象使用弱引用计数技术，而当垃圾收集系统执行对象回收工作时，只要发现对象的强引用计数为0，而不管它的弱引用计数是否为0，都可以回收这个对象，但是，如果我们只对一个对象持有弱引用计数，当我们要使用这个对象时，就不直接使用了，必须要把这个弱引用升级成为强引用时，才能使用这个对象，在转换的过程中，如果对象已经不存在，那么转换就失败了，这时候就说明这个对象已经被销毁了，不能再使用了。

了解了这些背景知识后，我们就可以进一步学习Android系统的智能指针的实现原理了。Android系统提供了强大的智能指针技术供我们使用，这些智能指针实现方案既包括简单的引用计数技术，也包括了复杂的引用计数技术，即对象既有强引用计数，也有弱引用计数，对应地，这三种智能指针分别就称为轻量级指针（Light Pointer）、强指针（Strong Pointer）和弱指针（Weak Pointer）。无论是轻量级指针，还是强指针和弱指针，它们的实现框架都是一致的，即由对象本身来提供引用计数器，但是它不会去维护这个引用计数器的值，而是由智能指针来维护，就好比是对象提供素材，但是具体怎么去使用这些素材，就交给智能指针来处理了。由于不管是什么类型的对象，它都需要提供引用计数器这个素材，在C++中，我们就可以把这个引用计数器素材定义为一个公共类，这个类只有一个成员变量，那就是引用计数成员变量，其它提供智能指针引用的对象，都必须从这个公共类继承下来，这样，这些不同的对象就天然地提供了引用计数器给智能指针使用了。总的来说就是我们在实现智能指会的过程中，第一是要定义一个负责提供引用计数器的公共类，第二是我们要实现相应的智能指针对象类，后面我们会看到这种方案是怎么样实现的。

## LightRefBase

```cpp
template <class T>
class LightRefBase
{
public:
    inline LightRefBase() : mCount(0) { }

    inline void incStrong(__attribute__((unused)) const void* id) const {
        mCount.fetch_add(1, std::memory_order_relaxed);
    }

    inline void decStrong(__attribute__((unused)) const void* id) const {
	//使用了 Release-Acquire ordering 同步模型，保证了在删除指针之前所有的 fetch_sub 操作都完成。
        if (mCount.fetch_sub(1, std::memory_order_release) == 1) {
            std::atomic_thread_fence(std::memory_order_acquire);
            delete static_cast<const T*>(this);
        }
    }

    //! DEBUGGING ONLY: Get current strong ref count.
    inline int32_t getStrongCount() const {
        return mCount.load(std::memory_order_relaxed);
    }

    typedef LightRefBase<T> basetype;

protected:
    inline ~LightRefBase() { }

private:
    friend class ReferenceMover;
    inline static void renameRefs(size_t /*n*/, const ReferenceRenamer& /*renamer*/) { }
    inline static void renameRefId(T* /*ref*/, const void* /*old_id*/ , const void* /*new_id*/) { }

private:
    mutable std::atomic<int32_t> mCount;
};
```

这个类很简单，它只一个成员变量 mCount，这就是引用计数器了，它的初始化值为 0，另外，这个类还提供两个成员函数 incStrong 和 decStrong 来维护引用计数器的值，这两个函数就是提供给智能指针来调用的了，这里要注意的是，在 decStrong 函数中，如果当前引用计数值为 1，那么当减 1 后就会变成 0，于是就会 delete 这个对象。

对 Memory Order 不了解的同学可以看下 [理解 C++ 的 Memory Order](https://github.com/ahaoddu/AndroidKnowledgeHierarchy/blob/main/%E7%90%86%E8%A7%A3%20C%2B%2B%20%E7%9A%84%20Memory%20Order.md) 这篇文章，这里使用了 Release-Acquire ordering 同步模型，保证了在删除指针之前所有的 fetch_sub 操作都完成。


这个类很简单，它只一个成员变量mCount，这就是引用计数器了，它的初始化值为0，另外，这个类还提供两个成员函数incStrong和decStrong来维护引用计数器的值，这两个函数就是提供给智能指针来调用的了，这里要注意的是，在decStrong函数中，如果当前引用计数值为1，那么当减1后就会变成0，于是就会delete这个对象。


```cpp
template<typename T>
class sp {
public:
    inline sp() : m_ptr(nullptr) { }

    sp(T* other);  // NOLINT(implicit)
    sp(const sp<T>& other);
    sp(sp<T>&& other) noexcept;
    template<typename U> sp(U* other);  // NOLINT(implicit)
    template<typename U> sp(const sp<U>& other);  // NOLINT(implicit)
    template<typename U> sp(sp<U>&& other);  // NOLINT(implicit)

    ~sp();

    // Assignment

    sp& operator = (T* other);
    sp& operator = (const sp<T>& other);
    sp& operator=(sp<T>&& other) noexcept;

    template<typename U> sp& operator = (const sp<U>& other);
    template<typename U> sp& operator = (sp<U>&& other);
    template<typename U> sp& operator = (U* other);

    //! Special optimization for use by ProcessState (and nobody else).
    void force_set(T* other);

    // Reset

    void clear();

    // Accessors

    inline T&       operator* () const     { return *m_ptr; }
    inline T*       operator-> () const    { return m_ptr;  }
    inline T*       get() const            { return m_ptr; }
    inline explicit operator bool () const { return m_ptr != nullptr; }

    // Operators

    COMPARE_STRONG(==)
    COMPARE_STRONG(!=)
    COMPARE_STRONG_FUNCTIONAL(>, std::greater)
    COMPARE_STRONG_FUNCTIONAL(<, std::less)
    COMPARE_STRONG_FUNCTIONAL(<=, std::less_equal)
    COMPARE_STRONG_FUNCTIONAL(>=, std::greater_equal)

    // Punt these to the wp<> implementation.
    template<typename U>
    inline bool operator == (const wp<U>& o) const {
        return o == *this;
    }

    template<typename U>
    inline bool operator != (const wp<U>& o) const {
        return o != *this;
    }

private:  
    template<typename Y> friend class sp;
    template<typename Y> friend class wp;
    void set_pointer(T* ptr);
    T* m_ptr;
};
```


```cpp
class RefBase
{
public:
            void            incStrong(const void* id) const;
            void            decStrong(const void* id) const;
  
            void            forceIncStrong(const void* id) const;

            //! DEBUGGING ONLY: Get current strong ref count.
            int32_t         getStrongCount() const;

            weakref_type*   createWeak(const void* id) const;
  
            weakref_type*   getWeakRefs() const;

            //! DEBUGGING ONLY: Print references held on object.
    inline  void            printRefs() const { getWeakRefs()->printRefs(); }

            //! DEBUGGING ONLY: Enable tracking of object.
    inline  void            trackMe(bool enable, bool retain)
    { 
        getWeakRefs()->trackMe(enable, retain); 
    }

    typedef RefBase basetype;

protected:
                            RefBase();
    virtual                 ~RefBase();
  
    //! Flags for extendObjectLifetime()
    enum {
        OBJECT_LIFETIME_STRONG  = 0x0000,
        OBJECT_LIFETIME_WEAK    = 0x0001,
        OBJECT_LIFETIME_MASK    = 0x0001
    };
  
            void            extendObjectLifetime(int32_t mode);
  
    //! Flags for onIncStrongAttempted()
    enum {
        FIRST_INC_STRONG = 0x0001
    };
  
    // Invoked after creation of initial strong pointer/reference.
    virtual void            onFirstRef();
    // Invoked when either the last strong reference goes away, or we need to undo
    // the effect of an unnecessary onIncStrongAttempted.
    virtual void            onLastStrongRef(const void* id);
    // Only called in OBJECT_LIFETIME_WEAK case.  Returns true if OK to promote to
    // strong reference. May have side effects if it returns true.
    // The first flags argument is always FIRST_INC_STRONG.
    // TODO: Remove initial flag argument.
    virtual bool            onIncStrongAttempted(uint32_t flags, const void* id);
    // Invoked in the OBJECT_LIFETIME_WEAK case when the last reference of either
    // kind goes away.  Unused.
    // TODO: Remove.
    virtual void            onLastWeakRef(const void* id);

private:
    friend class weakref_type;
    class weakref_impl;
  
                            RefBase(const RefBase& o);
            RefBase&        operator=(const RefBase& o);

private:
    friend class ReferenceMover;

    static void renameRefs(size_t n, const ReferenceRenamer& renamer);

    static void renameRefId(weakref_type* ref,
            const void* old_id, const void* new_id);

    static void renameRefId(RefBase* ref,
            const void* old_id, const void* new_id);

        weakref_impl* const mRefs;
};
```


## 参考资料

* [Android系统的智能指针（轻量级指针、强指针和弱指针）的实现原理分析](https://blog.csdn.net/Luoshengyang/article/details/6786239)
* 《深入理解Android》 卷一 第五章
