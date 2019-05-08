//
//  FFVertexMatrix.h
//  GoPlay
//
//  Created by dKingbin on 2018/10/17.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#ifndef FFVertexMatrix_h
#define FFVertexMatrix_h

static const GLfloat gl_vertices[] = {
	-1.0, -1.0f,
	1.0f, -1.0f,
	-1.0f, 1.0f,
	1.0f, 1.0f,
};
/*
 3    4
 1    2
 */

static const GLfloat opengl_textureCoords_R0[] = {
	0.0f, 0.0f,
	1.0f, 0.0f,
	0.0f, 1.0f,
	1.0f, 1.0f,
};
/*
 3    4
 1    2
 */

static const GLfloat opengl_textureCoords_R90[] = {
	0.0f, 1.0f,
	0.0f, 0.0f,
	1.0f, 1.0f,
	1.0f, 0.0f,
};
/*
 1    3
 2    4
 */

//180/not mirror
static const GLfloat opengl_textureCoords_R180[] = {
	1.0f, 1.0f,
	0.0f, 1.0f,
	1.0f, 0.0f,
	0.0f, 0.0f,
};
/*
 2    1
 4    3
 */

static const GLfloat opengl_textureCoords_R270[] = {
	1.0f, 0.0f,
	1.0f, 1.0f,
	0.0f, 0.0f,
	0.0f, 1.0f,
};
/*
 4    2
 3    1
 */

static const GLfloat glkit_textureCoords_R0[] = {
	0.0f, 1.0f,
	1.0f, 1.0f,
	0.0f, 0.0f,
	1.0f, 0.0f,
};
/*
 3    4
 1    2
 */

//rotate right
static const GLfloat glkit_textureCoords_R90[] = {
	1.0f, 1.0f,
	1.0f, 0.0f,
	0.0f, 1.0f,
	0.0f, 0.0f,
};
/*
 4    2
 3    1
 */

//180/not mirror
static const GLfloat glkit_textureCoords_R180[] = {
	1.0f, 0.0f,
	0.0f, 0.0f,
	1.0f, 1.0f,
	0.0f, 1.0f,
};
/*
 2    1
 4    3
 */

//rotate left
static const GLfloat glkit_textureCoords_R270[] = {
	0.0f, 0.0f,
	0.0f, 1.0f,
	1.0f, 0.0f,
	1.0f, 1.0f,
};
/*
 1    3
 2    4
 */

__unused static const GLfloat* opengl_rotate_matrix(FFRotationMode mode)
{
	switch (mode) {
		case FFRotationMode_R0:
			return opengl_textureCoords_R0;
			break;
		case FFRotationMode_R90:
			return opengl_textureCoords_R90;
			break;
		case FFRotationMode_R180:
			return opengl_textureCoords_R180;
			break;
		case FFRotationMode_R270:
			return opengl_textureCoords_R270;
			break;
		default:
			break;
	}

	return opengl_textureCoords_R0;
}

__unused static const GLfloat* glkit_rotate_matrix(FFRotationMode mode)
{
	switch (mode) {
		case FFRotationMode_R0:
			return glkit_textureCoords_R0;
			break;
		case FFRotationMode_R90:
			return glkit_textureCoords_R90;
			break;
		case FFRotationMode_R180:
			return glkit_textureCoords_R180;
			break;
		case FFRotationMode_R270:
			return glkit_textureCoords_R270;
			break;
		default:
			break;
	}

	return glkit_textureCoords_R0;
}

__unused static const GLfloat* gl_vertex_matrix()
{
	return gl_vertices;
}

__unused static bool ff_swap_wh(const FFRotationMode mode)
{
	if(mode == FFRotationMode_R90 || mode == FFRotationMode_R270) return true;
	return false;
}

#endif /* FFVertexMatrix_h */
