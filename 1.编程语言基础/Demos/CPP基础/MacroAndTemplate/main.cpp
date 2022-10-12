#include <iostream>
#include <assert.h>
#include "header.h"

//定义常量
#define PI 3.14
//定义类型
#define MY_DOUBLE double

//定义函数
#define SQUARE(x) ((x) * (x))
#define MIN(a, b) (((a) < (b)) ? (a) : (b))

using namespace std;

//模板函数
template<typename T>
const T &GetMax(const T &value1, const T &value2) {
    if (value1 > value2) {
        return value1;
    } else {
        return value2;
    }
}




int main() {
    MY_DOUBLE radius = 3;
    MY_DOUBLE result = PI * radius * radius;
    std::cout << "Area is " << result << std::endl;
    std::cout << "Square 5 is " << SQUARE(5) << std::endl;

    std::cout << "GetMax(5,6) is " << GetMax(5, 6) << std::endl;
    char *sayHello = nullptr;
    //#undef NDEBUG
    //没有定义 NDEBUG 宏才会执行
    //assert(sayHello != nullptr);

    //模板类使用
    HoldsPair<> pair1(36, 9.9);
    HoldsPair<short, const char *> pair2(28, "hello");

    //模板类的静态成员
    TestStatic<int>::staticval = 2;
    //TestStatic<int>::staticval = 3;
    //TestStatic<int>::staticval = 4;
    TestStatic<double>::staticval = 12;
    cout << "TestStatic<int>::staticval is " << TestStatic<int>::staticval << endl;
    cout << "TestStatic<double>::staticval is " << TestStatic<double>::staticval << endl;

    while(1) {}
    return 0;
}
