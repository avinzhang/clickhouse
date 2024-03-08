db = db.getSiblingDB('sample_db');
db.createUser(
  {
    user: "testuser",
    pwd: "password",
    roles: [
      {
        role: "readWrite",
        db: "sample_db"
      }
    ]
  }
);

db.createCollection('sample_collection');

db.sample_collection.insertMany([
 {
    id: 1,
    org: 'helpdev',
    filter: 'EVENT_A'
  },
  {
    id: 2,
    org: 'helpdev',
    filter: 'EVENT_B'
  },
  {
    id: 3,
    org: 'github',
    filter: 'EVENT_C'
  }  
]);
