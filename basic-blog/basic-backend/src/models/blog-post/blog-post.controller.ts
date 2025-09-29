import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';

import { RequireAuth } from '../../authentication/decorator/require-auth.decorator';

import { BlogPostService } from './blog-post.service';
import { CreateBlogPostDto } from './dto/create-blog-post.dto';
import { UpdateBlogPostDto } from './dto/update-blog-post.dto';

@Controller('blog-post')
export class BlogPostController {
  constructor(private readonly blogPostService: BlogPostService) {}

  @Get()
  findAll(
    @Query('query') query?: string,
    @Query('page') page = 1,
    @Query('limit') limit = 10,
  ) {
    return this.blogPostService.findAll(page, limit, query);
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.blogPostService.findOne(+id);
  }

  @Post()
  @RequireAuth()
  create(@Body() createBlogPostDto: CreateBlogPostDto) {
    return this.blogPostService.create(createBlogPostDto);
  }

  @Patch(':id')
  @RequireAuth()
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() updateBlogPostDto: UpdateBlogPostDto,
  ) {
    return this.blogPostService.update(+id, updateBlogPostDto);
  }

  @Delete(':id')
  @RequireAuth()
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.blogPostService.remove(+id);
  }

  @Delete('index')
  @RequireAuth()
  reindexAll() {
    return this.blogPostService.reindexAll();
  }
}
