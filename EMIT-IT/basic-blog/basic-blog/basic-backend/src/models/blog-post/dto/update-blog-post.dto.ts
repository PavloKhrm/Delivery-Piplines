import { IsNotEmpty, IsString, IsOptional, MaxLength } from 'class-validator';

export class UpdateBlogPostDto {
  @IsOptional()
  @IsNotEmpty()
  @IsString()
  @MaxLength(255)
  title: string;

  @IsOptional()
  @IsNotEmpty()
  @IsString()
  @MaxLength(5000)
  content: string;
}
