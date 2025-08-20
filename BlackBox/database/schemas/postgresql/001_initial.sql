-- Core database schema for Allixios Samurai
CREATE SCHEMA IF NOT EXISTS allixios;

-- Articles table
CREATE TABLE allixios.articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(500) UNIQUE NOT NULL,
    title VARCHAR(1000) NOT NULL,
    content TEXT NOT NULL,
    language VARCHAR(10) DEFAULT 'en',
    status VARCHAR(20) DEFAULT 'draft',
    seo_score INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    published_at TIMESTAMPTZ
);

-- SEO rankings table
CREATE TABLE allixios.rankings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id UUID REFERENCES allixios.articles(id),
    keyword VARCHAR(500) NOT NULL,
    position INTEGER,
    search_volume INTEGER,
    tracked_at DATE DEFAULT CURRENT_DATE
);

-- Revenue tracking
CREATE TABLE allixios.revenue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL,
    source VARCHAR(50) NOT NULL,
    amount DECIMAL(10,2) DEFAULT 0,
    article_id UUID REFERENCES allixios.articles(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_articles_status ON allixios.articles(status, published_at DESC);
CREATE INDEX idx_rankings_performance ON allixios.rankings(tracked_at DESC, position ASC);
CREATE INDEX idx_revenue_date ON allixios.revenue(date DESC, amount DESC);
