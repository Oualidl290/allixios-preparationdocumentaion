#!/usr/bin/env node

/**
 * Comprehensive Health Check Script
 * Tests all system components and reports status
 */

const { createClient } = require('@supabase/supabase-js');
const Redis = require('ioredis');

// Load environment variables
require('dotenv').config({ path: process.env.NODE_ENV === 'production' ? '.env.production' : '.env.development' });

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const REDIS_URL = process.env.REDIS_URL;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

console.log('🏥 Allixios Platform Health Check');
console.log('='.repeat(50));

async function checkDatabase() {
  console.log('\n📊 Database Health Check...');
  
  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
      throw new Error('Missing Supabase credentials');
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    
    // Test basic connectivity
    const start = Date.now();
    const { data, error } = await supabase
      .from('tenants')
      .select('count')
      .limit(1);
    
    const latency = Date.now() - start;
    
    if (error) {
      throw new Error(`Database query failed: ${error.message}`);
    }
    
    console.log(`   ✅ Database: Connected (${latency}ms)`);
    console.log(`   📍 URL: ${SUPABASE_URL}`);
    
    // Test function availability
    try {
      const { data: funcData, error: funcError } = await supabase.rpc('get_tenant_usage_stats', {
        p_tenant_id: '00000000-0000-0000-0000-000000000001'
      });
      
      if (!funcError) {
        console.log('   ✅ Database Functions: Available');
      } else {
        console.log('   ⚠️  Database Functions: Some functions may not be deployed');
      }
    } catch (funcErr) {
      console.log('   ⚠️  Database Functions: Not fully deployed');
    }
    
    return { status: 'healthy', latency };
  } catch (error) {
    console.log(`   ❌ Database: ${error.message}`);
    return { status: 'unhealthy', error: error.message };
  }
}

async function checkRedis() {
  console.log('\n🔄 Redis Health Check...');
  
  try {
    if (!REDIS_URL || REDIS_URL === 'redis://localhost:6379') {
      console.log('   ⚠️  Redis: Using localhost (development mode)');
      console.log('   💡 For production, configure Redis Cloud or Upstash');
      return { status: 'development', message: 'Using localhost Redis' };
    }

    const redis = new Redis(REDIS_URL, {
      connectTimeout: 5000,
      lazyConnect: true,
      maxRetriesPerRequest: 1
    });
    
    const start = Date.now();
    await redis.ping();
    const latency = Date.now() - start;
    
    // Test basic operations
    await redis.set('health_check', Date.now(), 'EX', 60);
    const value = await redis.get('health_check');
    await redis.del('health_check');
    
    if (!value) {
      throw new Error('Redis read/write test failed');
    }
    
    console.log(`   ✅ Redis: Connected (${latency}ms)`);
    console.log(`   📍 URL: ${REDIS_URL.replace(/\/\/.*@/, '//***@')}`);
    
    await redis.disconnect();
    return { status: 'healthy', latency };
  } catch (error) {
    console.log(`   ❌ Redis: ${error.message}`);
    console.log('   💡 Redis is optional for basic functionality');
    return { status: 'unhealthy', error: error.message };
  }
}

async function checkStorage() {
  console.log('\n📁 Storage Health Check...');
  
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    
    const { data, error } = await supabase.storage.listBuckets();
    
    if (error) {
      throw new Error(`Storage access failed: ${error.message}`);
    }
    
    const bucketCount = data.length;
    const expectedBuckets = ['media', 'private', 'cache', 'backups'];
    const existingBuckets = data.map(b => b.name);
    const missingBuckets = expectedBuckets.filter(b => !existingBuckets.includes(b));
    
    console.log(`   ✅ Storage: Accessible (${bucketCount} buckets)`);
    console.log(`   📦 Buckets: ${existingBuckets.join(', ')}`);
    
    if (missingBuckets.length > 0) {
      console.log(`   ⚠️  Missing buckets: ${missingBuckets.join(', ')}`);
    }
    
    return { 
      status: 'healthy', 
      buckets: existingBuckets,
      missing: missingBuckets 
    };
  } catch (error) {
    console.log(`   ❌ Storage: ${error.message}`);
    return { status: 'unhealthy', error: error.message };
  }
}

async function checkAI() {
  console.log('\n🤖 AI Services Health Check...');
  
  try {
    if (!GEMINI_API_KEY) {
      throw new Error('Missing Gemini API key');
    }
    
    // Test Gemini API (basic validation)
    if (GEMINI_API_KEY.startsWith('AIza') && GEMINI_API_KEY.length > 30) {
      console.log('   ✅ Gemini API: Key format valid');
      console.log(`   🔑 Key: ${GEMINI_API_KEY.substring(0, 10)}...`);
    } else {
      throw new Error('Invalid Gemini API key format');
    }
    
    // Note: We don't test actual API calls in health check to avoid quota usage
    console.log('   💡 API functionality will be tested during actual usage');
    
    return { status: 'configured', provider: 'gemini' };
  } catch (error) {
    console.log(`   ❌ AI Services: ${error.message}`);
    return { status: 'unhealthy', error: error.message };
  }
}

async function checkEnvironment() {
  console.log('\n🔧 Environment Health Check...');
  
  const requiredVars = [
    'SUPABASE_URL',
    'SUPABASE_SERVICE_ROLE_KEY',
    'GEMINI_API_KEY'
  ];
  
  const optionalVars = [
    'REDIS_URL',
    'JWT_SECRET',
    'ENCRYPTION_KEY'
  ];
  
  let missingRequired = [];
  let missingOptional = [];
  
  requiredVars.forEach(varName => {
    if (!process.env[varName]) {
      missingRequired.push(varName);
    } else {
      console.log(`   ✅ ${varName}: Set`);
    }
  });
  
  optionalVars.forEach(varName => {
    if (!process.env[varName]) {
      missingOptional.push(varName);
    } else {
      console.log(`   ✅ ${varName}: Set`);
    }
  });
  
  if (missingRequired.length > 0) {
    console.log(`   ❌ Missing required: ${missingRequired.join(', ')}`);
    return { status: 'unhealthy', missing: missingRequired };
  }
  
  if (missingOptional.length > 0) {
    console.log(`   ⚠️  Missing optional: ${missingOptional.join(', ')}`);
  }
  
  console.log(`   🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
  
  return { 
    status: 'healthy', 
    missing_optional: missingOptional 
  };
}

async function generateReport(results) {
  console.log('\n' + '='.repeat(50));
  console.log('📋 HEALTH CHECK SUMMARY');
  console.log('='.repeat(50));
  
  const components = [
    { name: 'Environment', result: results.environment },
    { name: 'Database', result: results.database },
    { name: 'Storage', result: results.storage },
    { name: 'Redis Cache', result: results.redis },
    { name: 'AI Services', result: results.ai }
  ];
  
  let healthyCount = 0;
  let totalCount = components.length;
  
  components.forEach(({ name, result }) => {
    const status = result.status;
    let icon = '❌';
    
    if (status === 'healthy') {
      icon = '✅';
      healthyCount++;
    } else if (status === 'development' || status === 'configured') {
      icon = '⚠️ ';
      healthyCount += 0.5;
    }
    
    console.log(`${icon} ${name}: ${status}`);
    
    if (result.latency) {
      console.log(`   ⏱️  Latency: ${result.latency}ms`);
    }
    
    if (result.error) {
      console.log(`   💬 ${result.error}`);
    }
  });
  
  const healthPercentage = Math.round((healthyCount / totalCount) * 100);
  
  console.log('\n📊 Overall Health: ' + healthPercentage + '%');
  
  if (healthPercentage >= 80) {
    console.log('🎉 System is ready for operation!');
  } else if (healthPercentage >= 60) {
    console.log('⚠️  System has some issues but may be functional');
  } else {
    console.log('❌ System requires attention before operation');
  }
  
  console.log('\n🚀 Next Steps:');
  if (results.redis.status === 'development') {
    console.log('1. Set up Redis Cloud or Upstash for production caching');
  }
  if (results.storage.missing && results.storage.missing.length > 0) {
    console.log('2. Create missing storage buckets via Supabase dashboard');
  }
  if (results.environment.missing_optional && results.environment.missing_optional.length > 0) {
    console.log('3. Configure optional environment variables for enhanced features');
  }
  console.log('4. Deploy your microservices and start building!');
  
  console.log('\n📚 Resources:');
  console.log(`- Supabase Dashboard: ${SUPABASE_URL.replace('https://', 'https://supabase.com/dashboard/project/')}`);
  console.log('- Documentation: ./README.md');
  console.log('- Deployment Guide: ./DEPLOYMENT-STRATEGY.md');
  
  return healthPercentage >= 60;
}

async function main() {
  try {
    const results = {
      environment: await checkEnvironment(),
      database: await checkDatabase(),
      storage: await checkStorage(),
      redis: await checkRedis(),
      ai: await checkAI()
    };
    
    const isHealthy = await generateReport(results);
    process.exit(isHealthy ? 0 : 1);
  } catch (error) {
    console.error('\n💥 Health check failed:', error.message);
    process.exit(1);
  }
}

// Run health check
main();