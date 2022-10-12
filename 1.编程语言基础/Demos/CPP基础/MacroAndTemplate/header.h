//
// Created by zzh0838 on 2022/9/26.
//
//头文件避免重复包含
#ifndef MACROANDTEMPLATE_HEADER_H
#define MACROANDTEMPLATE_HEADER_H

//模板类
template<typename T1=int, typename T2=double>
class HoldsPair {
private:
    T1 value1;
    T2 value2;
public:
    HoldsPair(const T1 &val1, const T2 &val2) : value1(val1), value2(val2) {}

    const T1 &getFirstValue() const {
        return value1;
    }

    const T2 &getSecondValue() const {
        return value2;
    }
};

//模板类的具体化
template<typename T1=int, typename T2=double>
class HoldsPair2 {
private:
    T1 value1;
    T2 value2;
public:
    HoldsPair2(const T1 &val1, const T2 &val2) : value1(val1), value2(val2) {}

    const T1 &getFirstValue() const;

    const T2 &getSecondValue() const;
};

template<>
class HoldsPair2<int, int> {
private:
    int value1;
    int value2;
public:
    HoldsPair2(const int &val1, const int &val2) : value1(val1), value2(val2) {}

    const int &getFirstValue() const {
        return value1;
    }

    const int &getSecondValue() const {
        return value2;
    }
};

template<typename T>
class TestStatic {
public:
    static int staticval;
};
template<typename T> int TestStatic<T>::staticval = 999;
#endif //MACROANDTEMPLATE_HEADER_H
