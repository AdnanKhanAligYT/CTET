-- Sample content for CTET Paper 2 so Mock Test / Syllabus / Dictionary
-- aren't empty on first run. Run this once in Supabase SQL Editor after
-- schema.sql. Safe to delete/replace later with real content.

insert into public.questions (subject, topic, exam_tags, text, options, correct_option_index, explanations) values
('Child Development and Pedagogy', 'Piaget''s Theory', '{"CTET Paper 2"}',
 'According to Piaget, at which stage does a child develop the ability to think abstractly?',
 '{"Sensorimotor","Preoperational","Concrete Operational","Formal Operational"}', 3,
 '{"This is the earliest stage (birth to 2 years), based on sensory experience, not abstract thought.","Children age 2-7 use symbols but cannot yet reason abstractly.","Children age 7-11 reason logically but only about concrete objects.","Correct — from age 11 onward, children can think abstractly and hypothetically."}'),

('Child Development and Pedagogy', 'Inclusive Education', '{"CTET Paper 2"}',
 'Inclusive education primarily means:',
 '{"Educating children with disabilities in separate special schools","Educating all children, including those with disabilities, together in the same classroom","Only providing extra textbooks to weaker students","Grouping students strictly by academic ability"}', 1,
 '{"This describes segregated, not inclusive, education.","Correct — inclusive education means all children learn together, with support as needed.","This is a resource provision, not the definition of inclusion.","This describes ability tracking, the opposite of inclusive practice."}'),

('Mathematics', 'Number System', '{"CTET Paper 2"}',
 'What is the smallest prime number?',
 '{"0","1","2","3"}', 2,
 '{"0 is neither prime nor composite.","1 is neither prime nor composite by definition.","Correct — 2 is the smallest and only even prime number.","3 is prime, but not the smallest."}'),

('Environmental Studies', 'Our Environment', '{"CTET Paper 2"}',
 'Which of the following is a renewable source of energy?',
 '{"Coal","Petroleum","Solar energy","Natural gas"}', 2,
 '{"Coal is a fossil fuel and non-renewable.","Petroleum is a fossil fuel and non-renewable.","Correct — sunlight is naturally replenished and renewable.","Natural gas is a fossil fuel and non-renewable."}'),

('Language Pedagogy', 'Language Acquisition', '{"CTET Paper 2"}',
 'A child learns their first language mainly through:',
 '{"Formal grammar instruction","Natural exposure and interaction with the environment","Memorizing dictionaries","Written practice alone"}', 1,
 '{"Formal grammar teaching happens later, not during first-language acquisition.","Correct — children acquire their first language naturally through exposure and interaction.","This is not how first-language acquisition happens in early childhood.","Written practice comes only after basic language is already acquired."}');

insert into public.syllabus_topics (exam, subject, unit, topic_name, "order") values
('CTET Paper 2', 'Child Development and Pedagogy', 'Unit 1', 'Development of Child: Piaget, Kohlberg, Vygotsky', 1),
('CTET Paper 2', 'Child Development and Pedagogy', 'Unit 1', 'Inclusive Education and Diversity', 2),
('CTET Paper 2', 'Child Development and Pedagogy', 'Unit 2', 'Learning and Pedagogy', 3),
('CTET Paper 2', 'Mathematics', 'Unit 1', 'Number System', 4),
('CTET Paper 2', 'Mathematics', 'Unit 2', 'Geometry and Mensuration', 5),
('CTET Paper 2', 'Environmental Studies', 'Unit 1', 'Family and Friends', 6),
('CTET Paper 2', 'Environmental Studies', 'Unit 2', 'Food and Shelter', 7),
('CTET Paper 2', 'Language Pedagogy', 'Unit 1', 'Language Acquisition and Learning', 8);

insert into public.dictionary_words (word, meaning_hi, meaning_en, example_sentence) values
('Pedagogy', 'शिक्षण शास्त्र', 'The method and practice of teaching', 'Good pedagogy adapts to how each child learns.'),
('Cognition', 'संज्ञान', 'The mental process of acquiring knowledge and understanding', 'Piaget studied the stages of cognition in children.'),
('Inclusive', 'समावेशी', 'Including everyone, especially those often excluded', 'The school follows an inclusive admission policy.'),
('Curriculum', 'पाठ्यक्रम', 'The subjects and content taught in a course of study', 'The new curriculum focuses more on activity-based learning.'),
('Assessment', 'मूल्यांकन', 'The process of evaluating a student''s learning', 'Continuous assessment replaced the single final exam.');
