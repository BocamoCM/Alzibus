const pool = require('./db');
pool.query("SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_name = 'stops'")
  .then(res => console.log(res.rows))
  .catch(e => console.error(e))
  .finally(() => pool.end());
