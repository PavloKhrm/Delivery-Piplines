import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('blog_posts')
export class BlogPost {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({
    length: 255,
    nullable: false,
  })
  title: string;

  @Column({
    nullable: false,
    length: 5000,
  })
  content: string;

  @Column({
    type: 'timestamp',
    default: () => 'CURRENT_TIMESTAMP',
  })
  createdAt: Date;

  @Column({
    type: 'timestamp',
    default: () => 'CURRENT_TIMESTAMP',
    onUpdate: 'CURRENT_TIMESTAMP',
  })
  updatedAt: Date;
}
