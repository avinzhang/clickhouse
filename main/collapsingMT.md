CREATE TABLE messages
(
    id UInt32,
    day Date,
    message String,
    sign Int8
)
ENGINE = CollapsingMergeTree(sign)
ORDER BY id;

--insert some values
insert into messages (id, day, message, sign) VALUES (1, '2024-07-04', 'Hello', 1), (2, '2024-07-04', 'Hi', 1), (3, '2024-07-04', 'Bonjour', 1);

--update row with id equal to 2, setting the day to '2024-07-05' and changing the message to "Goodbye".  
insert into messages VALUES (2, '2024-07-05', 'Goodbye', 1);


--delete id 3
insert into messages (id, sign) VALUES (3, -1);








