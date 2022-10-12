package com.ahaoddu.main;

import com.ahaoddu.mytriangle.Triangle;

public class  TriangleDemo
{
	public static void main(String[] args) 
	{
		Triangle t1;
		t1 = new Triangle(3, 4, 5);
		System.out.println("t1 area : "+t1.areaFunc());
		System.out.println("t1 round :"+t1.zhouChangFunc());

	}
}
