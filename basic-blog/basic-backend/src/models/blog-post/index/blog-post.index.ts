import {
  IndicesAlias,
  IndicesIndexSettings,
  MappingTypeMapping,
  Name,
} from '@elastic/elasticsearch/lib/api/types';

import { BlogPost } from '../entities/blog-post.entity';

export const blogPostProperties: MappingTypeMapping['properties'] = {
  id: {
    type: 'integer',
  },
  title: {
    type: 'text',
    analyzer: 'ngram_analyzer',
    fields: {
      keyword: {
        type: 'keyword',
      },
    },
  },
  content: {
    type: 'text',
    analyzer: 'ngram_analyzer',
  },
  createdAt: {
    type: 'date',
    format: 'strict_date_optional_time||epoch_millis',
  },
  updatedAt: {
    type: 'date',
    format: 'strict_date_optional_time||epoch_millis',
  },
};

export const BLOG_POST_INDEX = 'blog-posts';

export const blogPostIndexMapping: {
  aliases?: Record<Name, IndicesAlias>;
  mappings?: MappingTypeMapping;
  settings?: IndicesIndexSettings;
} = {
  settings: {
    index: {
      max_ngram_diff: 17,
    },
    analysis: {
      tokenizer: {
        edge_ngram_tokenizer: {
          type: 'edge_ngram',
          min_gram: 3,
          max_gram: 20,
          token_chars: ['letter', 'digit'],
        },
        ngram_tokenizer: {
          type: 'ngram',
          min_gram: 3,
          max_gram: 20,
          token_chars: ['letter', 'digit'],
        },
      },
      analyzer: {
        edge_ngram_analyzer: {
          type: 'custom',
          tokenizer: 'edge_ngram_tokenizer',
          filter: ['lowercase'],
        },
        ngram_analyzer: {
          type: 'custom',
          tokenizer: 'ngram_tokenizer',
          filter: ['lowercase'],
        },
        custom_text_analyzer: {
          type: 'custom',
          tokenizer: 'standard',
          filter: ['lowercase', 'word_delimiter_graph'],
        },
      },
      char_filter: {
        trim_whitespace: {
          type: 'pattern_replace',
          pattern: '^\\s+|\\s+$',
          replacement: '',
        },
      },
      normalizer: {
        lowercase_normalizer: {
          type: 'custom',
          char_filter: [],
          filter: ['lowercase'],
        },
        trim_lowercase_normalizer: {
          type: 'custom',
          char_filter: ['trim_whitespace'],
          filter: ['lowercase'],
        },
      },
    },
  },
  mappings: {
    properties: blogPostProperties,
  },
};

export const transformEntityToIndex = (entity: BlogPost) => ({
  id: entity.id,
  title: entity.title,
  content: entity.content,
  createdAt: entity.createdAt,
  updatedAt: entity.updatedAt,
});
