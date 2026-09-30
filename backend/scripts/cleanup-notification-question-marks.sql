UPDATE notifications
SET title = regexp_replace(title, '^[? ]+|[? ]+$', '', 'g')
WHERE title ~ '[?]';