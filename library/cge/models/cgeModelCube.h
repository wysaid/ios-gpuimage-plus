/*
* cgeModelCube.h
*
*  Created on: 2014-10-30
*      Author: Wang Yang
*        Mail: admin@wysaid.org
*/

#ifndef _CGEMODELCUBE_H_
#define _CGEMODELCUBE_H_

namespace CGE
{
	//使用 GL_TRIANGLES 方式绘制
	struct ModelCube
	{
		static const float vertices[];
		static const int vertDataSize = 3; // 每个顶点包含三个分量
		static const int vertSize;

		static const float vertTexture[]; // 纹理顶点
		static const int vertTextureSize; //每个纹理顶点包含两个分量

 		static const float vertNormals[]; //顶点法向量

 		static const unsigned short vertIndexes[];
		static const int vertIndexSize;
		
	};

	const float ModelCube::vertices[] = {
		1, 1, 1,  -1, 1, 1,  -1,-1, 1,  1,-1, 1, 
		1, 1, 1,  1,-1, 1,  1,-1,-1,  1, 1,-1,
		1, 1, 1,  1, 1,-1,  -1, 1,-1,  -1, 1, 1,
		-1, 1, 1,  -1, 1,-1,  -1,-1,-1,  -1,-1, 1,
		-1,-1,-1,  1,-1,-1,  1,-1, 1,  -1,-1, 1,
		1,-1,-1,  -1,-1,-1,  -1, 1,-1,  1, 1,-1
	};

	const unsigned short ModelCube::vertIndexes[] = {
		0, 1, 2,  0, 2, 3,
		4, 5, 6,  4, 6, 7,
		8, 9,10,  8,10,11,
		12,13,14,  12,14,15,
		16,17,18,  16,18,19,
		20,21,22,  20,22,23
	};

	const float ModelCube::vertTexture[] = {
		1, 1,  0, 1,  0, 0,  1, 0,
		0, 1,  0, 0,  1, 0,  1, 1,
		1, 0,  1, 1,  0, 1,  0, 0,
		1, 1,  0, 1,  0, 0,  1, 0,
		0, 0,  1, 0,  1, 1,  0, 1,
		0, 0,  1, 0,  1, 1,  0, 1
	};
    
    const float ModelCube::vertNormals[] = {
		0, 0, 1,  0, 0, 1,  0, 0, 1,  0, 0, 1,
		1, 0, 0,  1, 0, 0,  1, 0, 0,  1, 0, 0,
		0, 1, 0,  0, 1, 0,  0, 1, 0,  0, 1, 0,
		-1, 0, 0,  -1, 0, 0,  -1, 0, 0,  -1, 0, 0,
		0,-1, 0,  0,-1, 0,  0,-1, 0,  0,-1, 0,
		0, 0,-1,  0, 0,-1,  0, 0,-1,  0, 0,-1
	};

	const int ModelCube::vertSize = sizeof(ModelCube::vertices);
    const int ModelCube::vertTextureSize = sizeof(ModelCube::vertTexture);
	const int ModelCube::vertIndexSize = sizeof(ModelCube::vertIndexes);
}

#endif