// Class browser test: nested #if / #else, so the preprocessor's branch stack (a TIntList) is used.
#define FEATURE 1
#define LEVEL 3

#if FEATURE
class Shown {
public:
    int visible;
#if LEVEL > 2
    void deepMethod();
#else
    void shallowMethod();
#endif
};
#else
class Hidden {
    int never;
};
#endif

#if 0
class AlsoHidden { };
#elif LEVEL == 3
class LevelThree {
    void three();
};
#endif

int main() { return 0; }
