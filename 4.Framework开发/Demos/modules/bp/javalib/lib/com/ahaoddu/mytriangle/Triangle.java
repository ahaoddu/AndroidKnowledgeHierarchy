package com.ahaoddu.mytriangle;

public class Triangle
{
	private int a;
	private int b;
	private int c;

		
	public Triangle(int a, int b, int c)
	{
		this.a = a;
		this.b = b;
		this.c = c;
	}

		
	public Triangle()
	{
		this(9, 12, 15);
	}

	public int zhouChangFunc()
	{
		return (a+b+c);
	}

	public double areaFunc()
	{
		double p = zhouChangFunc()/2.0;

		return Math.sqrt(p*(p-a)*(p-b)*(p-c));
	}

}
