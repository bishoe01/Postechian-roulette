const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const supabaseUrl = 'https://ywuojdghqyozoiaaglbn.supabase.co';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseServiceKey) {
  console.error('Please set SUPABASE_SERVICE_KEY environment variable');
  console.log('\nTo run migrations, you need the service_role key from your Supabase project.');
  console.log('You can find it in: Supabase Dashboard > Settings > API > service_role key');
  console.log('\nThen run: SUPABASE_SERVICE_KEY="your-service-key" node run-migrations.js');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function runMigrations() {
  const migrationsDir = path.join(__dirname, 'supabase', 'migrations');
  const migrationFiles = [
    '001_create_schema.sql',
    '002_enable_rls.sql',
    '003_helper_functions.sql'
  ];

  for (const file of migrationFiles) {
    const filePath = path.join(migrationsDir, file);
    const sql = fs.readFileSync(filePath, 'utf8');
    
    console.log(`\nRunning migration: ${file}`);
    
    try {
      const { data, error } = await supabase.rpc('query', { query: sql });
      
      if (error) {
        console.error(`Error in ${file}:`, error.message);
        process.exit(1);
      }
      
      console.log(`✓ ${file} completed successfully`);
    } catch (err) {
      console.error(`Failed to run ${file}:`, err.message);
      process.exit(1);
    }
  }
  
  console.log('\n✅ All migrations completed successfully!');
}

runMigrations().catch(console.error);