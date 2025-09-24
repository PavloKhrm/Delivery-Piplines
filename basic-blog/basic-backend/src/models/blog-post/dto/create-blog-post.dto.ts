import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class CreateBlogPostDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(255)
  title: string;

  @IsNotEmpty()
  @IsString()
  @MaxLength(5000)
  content: string;
}
