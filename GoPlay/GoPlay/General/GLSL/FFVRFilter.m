//
//  FFVRFilter.m
//  GoPlay
//
//  Created by dKingbin on 2019/3/20.
//  Copyright © 2019 dKingbin. All rights reserved.
//

#import "FFVRFilter.h"
#import "FFGLContext.h"
#import "FFGLProgram.h"
#import "GLSL.h"

#import <GLKit/GLKit.h>

@interface FFVRFilter ()
{
	GLushort* index_buffer_data;
	GLfloat*  vertex_buffer_data;
	GLfloat*  texture_buffer_data;
}

@property(nonatomic,assign) GLuint vertex_buffer_id;
@property(nonatomic,assign) GLuint index_buffer_id;
@property(nonatomic,assign) GLuint texture_buffer_id;
@property(nonatomic,assign) int index_count;
@property(nonatomic,assign) int vertex_count;

@property(nonatomic,assign) GLuint mvp_id;
@end

@implementation FFVRFilter

- (instancetype)init
{
	self = [super init];

	if(self)
	{
        self.currentQuaterion = GLKQuaternionMake(0, 0, 0, 1);
    }

	return self;
}

- (void)setupVRParam
{
	static int const slices_count = 200;
	static int const parallels_count = slices_count / 2;	//100

	static int const index_count  = slices_count * parallels_count * 6;				//120000
	static int const vertex_count = (slices_count + 1) * (parallels_count + 1);		//20301

	self.index_count = index_count;
	self.vertex_count = vertex_count;

	float const step = (2.0f * M_PI) / (float)slices_count;		//0.0314159282
	float const radius = 1.0f;

	// model
	index_buffer_data = malloc(sizeof(GLushort) * index_count);
	vertex_buffer_data = malloc(sizeof(GLfloat) * 3 * vertex_count);
	texture_buffer_data = malloc(sizeof(GLfloat) * 2 * vertex_count);

	int runCount = 0;
	for (int i = 0; i < parallels_count + 1; i++)
	{
		for (int j = 0; j < slices_count + 1; j++)
		{
			int vertex = (i * (slices_count + 1) + j) * 3;	//0  3  6

			if (vertex_buffer_data)
			{
				vertex_buffer_data[vertex + 0] = radius * sinf(step * (float)i) * cosf(step * (float)j);	//x
				vertex_buffer_data[vertex + 1] = radius * cosf(step * (float)i);							//z
				vertex_buffer_data[vertex + 2] = radius * sinf(step * (float)i) * sinf(step * (float)j);	//y
			}

			if (texture_buffer_data)
			{
				int textureIndex = (i * (slices_count + 1) + j) * 2;						//0  2  4
				texture_buffer_data[textureIndex + 0] = (float)j / (float)slices_count;
				texture_buffer_data[textureIndex + 1] = ((float)i / (float)parallels_count);
			}

			if (index_buffer_data && i < parallels_count && j < slices_count)
			{
				index_buffer_data[runCount++] = i * (slices_count + 1) + j;					//0      1      2
				index_buffer_data[runCount++] = (i + 1) * (slices_count + 1) + j;			//201	 202	203
				index_buffer_data[runCount++] = (i + 1) * (slices_count + 1) + (j + 1);		//202    203	204

				index_buffer_data[runCount++] = i * (slices_count + 1) + j;					//0		 1		2
				index_buffer_data[runCount++] = (i + 1) * (slices_count + 1) + (j + 1);		//202    203	204
				index_buffer_data[runCount++] = i * (slices_count + 1) + (j + 1);			//1		 2		3
			}
		}
	}

	[[FFGLContext shareInstance] useCurrentContext];

	glGenBuffers(1, &_index_buffer_id);
	glGenBuffers(1, &_vertex_buffer_id);
	glGenBuffers(1, &_texture_buffer_id);

	//index
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _index_buffer_id);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, self.index_count * sizeof(GLushort), index_buffer_data, GL_STATIC_DRAW);

	//vertex
	glBindBuffer(GL_ARRAY_BUFFER, _vertex_buffer_id);
	glBufferData(GL_ARRAY_BUFFER, self.vertex_count * 3 * sizeof(GLfloat), vertex_buffer_data, GL_STATIC_DRAW);
	glVertexAttribPointer(self.positionId, 3, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(self.positionId);

	// texture coord
	glBindBuffer(GL_ARRAY_BUFFER, _texture_buffer_id);
	glBufferData(GL_ARRAY_BUFFER, self.vertex_count * 2 * sizeof(GLfloat), texture_buffer_data, GL_DYNAMIC_DRAW);
	glVertexAttribPointer(self.inputTextureCoordinateId, 2, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(self.inputTextureCoordinateId);

	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
}

- (GLKMatrix4)mvpMatrix
{
	float width = [UIScreen mainScreen].bounds.size.width;
	float height = [UIScreen mainScreen].bounds.size.height;

	float aspect = fabs(width / (float)height);
	GLKMatrix4 rotation = GLKMatrix4MakeWithQuaternion(self.currentQuaterion);

	GLKMatrix4 projection = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(60), aspect, 0.1, 400.0);
	GLKMatrix4 view = GLKMatrix4MakeLookAt(0.0, 0.0, 0.0, 0.0, 0.0, -1000.0, 0, 1, 0);
	GLKMatrix4 mvp = GLKMatrix4Multiply(projection, view);
	mvp = GLKMatrix4Multiply(mvp, rotation);
	
	return mvp;
}

#pragma mark -- didUpdateProgram
- (void)didUpdateProgram
{
	self.program = [[FFGLProgram alloc] initWithVertexShader:kFFVRVertexShaderString
											  fragmentShader:kFFPassthroughFragmentShaderString];
}

#pragma mark -- didUpdateParameter
- (void)didUpdateParameter
{
	[self setupVRParam];

	self.mvp_id = [self.program bindUniform:@"mvpMatrix"];
	GLKMatrix4 mvp = [self mvpMatrix];
	glUniformMatrix4fv(self.mvp_id, 1, GL_FALSE, mvp.m);
}

#pragma mark -- didUpdateFilter
- (void)didUpdateFilter
{
	//need to update every times

	//index
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, self.index_buffer_id);

	//vertex
	glBindBuffer(GL_ARRAY_BUFFER, self.vertex_buffer_id);
	glVertexAttribPointer(self.positionId, 3, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(self.positionId);

	// texture coord
	glBindBuffer(GL_ARRAY_BUFFER, self.texture_buffer_id);
	glVertexAttribPointer(self.inputTextureCoordinateId, 2, GL_FLOAT, GL_FALSE, 0, NULL);
	glEnableVertexAttribArray(self.inputTextureCoordinateId);

	//mvp matrix
	GLKMatrix4 mvp = [self mvpMatrix];
	glUniformMatrix4fv(self.mvp_id, 1, GL_FALSE, mvp.m);
}

#pragma mark -- didDrawCall
- (void)didDrawCall
{
	glDrawElements(GL_TRIANGLES, self.index_count, GL_UNSIGNED_SHORT, 0);
}

#pragma mark -- didEndUpdateFilter
- (void)didEndUpdateFilter
{
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
}

- (void)clearRenderBuffers
{
	[[FFGLContext shareInstance] useCurrentContext];

	if(self.index_buffer_id)
	{
		glDeleteBuffers(1, &_index_buffer_id);
		self.index_buffer_id = 0;
	}

	if(self.vertex_buffer_id)
	{
		glDeleteBuffers(1, &_vertex_buffer_id);
		self.vertex_buffer_id = 0;
	}

	if(self.texture_buffer_id)
	{
		glDeleteBuffers(1, &_texture_buffer_id);
		self.texture_buffer_id = 0;
	}
}

- (void)dealloc
{
	if(vertex_buffer_data)
	{
		free(vertex_buffer_data);
	}

	if(index_buffer_data)
	{
		free(index_buffer_data);
	}

	if(texture_buffer_data)
	{
		free(texture_buffer_data);
	}

	[self clearRenderBuffers];
}

@end
