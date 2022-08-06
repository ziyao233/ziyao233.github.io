# 洛谷-P1403

## 题目描述

科学家们在 Samuel 星球上的探险得到了丰富的能源储备，这使得空间站中大型计算机
Samuel II 的长时间运算成为了可能。由于在去年一年的辛苦工作取得了不错的成绩，
小联被允许用 Samuel II 进行数学研究。

小联最近在研究和约数有关的问题，他统计每个正数 $N$ 的约数的个数，
并以 $f(N)$ 来表示。例如 $12$ 的约数有 $1,2,3,4,6,12$，因此 $f(12)=6$。

现在请你求出：

$$
\sum_{i=1}^n f(i)
$$

## 输入格式

输入一个整数 $n$。

## 输出格式

输出答案。

## 样例 #1

### 样例输入 #1

```
3
```

### 样例输出 #1

```
5
```

## 提示

- 对于 $20\%$ 的数据，$N \leq 5000$；
- 对于 $100\%$ 的数据，$1 \leq N \leq 10^6$

## 思路

### 最简单的暴力

由于刷的都是暴力的题目，所以这道题先写了一个最直觉的解

```C
long int answer = 1;
for (int n = 2;n <= target;n++) {
	for (int k = 1;k <= n;k++) {
		answer = n % k ? answer : answer + 1;
	}
}
```

当然，十个点 TLE 了七个()，于是立刻放弃了。

### 筛法

利用埃氏筛法的思想，对于一个整数 k，它的倍数显然能被 k 整除。

```C++
long int *divisorNum = new long int[n];
assert(divisorNum);

long int answer = 1;
for (int i = 2;i <= target;i++) {
	answer += divisorNum[i] + 2;	// 1 和它本身
	for (int times = i;i <= target;times += i)
		divisorNum[times]++;
}
```

此法 AC，耗时正好 200ms。但是当我翻开题解...

### 数学法

From the description of $ f(i) $,we could rewrite it as
$$	f(i) = \sum ^{i} \_{k = 1} \[k | i\]	$$

Here,$ a | b $ meas that a is a divisor of b.

The mark,$ [ cond ] $,introduced in Iverson's APL and used widely in
_Concrete Mathematics_,means
$$
	[cond] = \begin{cases}
		1	&	\text{if cond is true} \\\\
		0	&	\text{else}
		\end{cases}
$$

Our answer is $ \sum \_{d = 1} ^{d} f(d) $,which is equal to
$$	\sum \_{d = 1} ^{n} \sum \_{k = 1} ^{d} [k | d]	$$
then
$$	\sum \_{d = 1} ^{n} \sum \_{k = 1} ^{n} [k | d] $$

The reason is that any number larger than k could not be k's divisor.
This change removes dependency of d in the inner summary,which makes the
next step easier.

Exchange the order to make it clearer
$$	\sum \_{k = 1} ^{n} \sum \_{d = 1} ^{n} [k | d]	$$

The problem,now,is transformed into that the number of multiples of k
between 1 and n.

This could be easily done.The answer is $ \lfloor \frac n k \rfloor $.

So we just need to compute
$$	\sum \_{k = 1} ^{n} \lfloor \frac n k \rfloor	$$
