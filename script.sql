-- Supra created a playground for us!
--
-- create table etl_reporting.stg_qlx_demo_survey
-- (
--     id                  varchar(64)                                                                 not null,
--     name                varchar(512)                                                                not null,
--     owner_id            varchar(64)                                                                 not null,
--     creator_id          varchar(64)                                                                 not null,
--     is_active           varchar(10)                                                                 not null,
--     last_activated_date varchar(32),
--     last_modified_date  varchar(32),
--     questions           super encode zstd,
--     batch_id            varchar(36) encode runlength,
--     etl_updated         timestamp with time zone default ('now'::text)::timestamp without time zone not null
-- )
--     diststyle all
--     sortkey (etl_updated);

-- Let's take a look at the data with which we are playing with
SELECT *
FROM etl_reporting.stg_qlx_demo_survey;

-- Let's analyze the structure of the data


---------------------------- Get the questions out of that mess
-- Baseline, easy, as the questions follow the same structure
-- description : question
-- choices : {answers}

-- dot and brackets notation

WITH cte AS
    (
        SELECT
            id,
            batch_id,
            last_modified_date::timestamptz,
            questions as json_str
        FROM etl_reporting.stg_qlx_demo_survey
    )
SELECT
    x.id,
    x.batch_id,
    x.last_modified_date,
    json_key as question_id,
    json_value.description AS question_body,
    json_value.choices AS answer_json_str,
    json_value.choices[0] AS first_available_answer
FROM cte AS x, x.json_str AS unnested, unpivot unnested AS json_value AT json_key
WHERE question_id = 'QID10'
ORDER BY question_id;

-- x becomes the alias for cte
-- unnested becomes the alias of x.json_str
-- unpivot -> split key and value pairs, as respectively json_key and json_value

-- The python equivalent would be something like:
-- for key, value in d.items():

-- or, keeping the variables/column names constant
-- for json_key, json_value in unnested.items():
--      question_id = json_key
--      question_body = json_value['description']
--      answer_json_str = json_value['choices']
--      first_available_answer = json_value['choices'][0]




-- Do we need a cte (Common Table Expression) here?
-- Absolutely not
-- Does it make reading the query a touch less unpleasant
-- Kinda
SELECT
    x.id,
    x.batch_id,
    x.last_modified_date::timestamptz,
    json_key as question_id,
    json_val.description AS question_body,
    json_val.choices AS answer_json_str,
    json_val.choices[0] AS first_available_answer
FROM etl_reporting.stg_qlx_demo_survey x, x.questions AS unnested, unpivot unnested AS json_val AT json_key
ORDER BY question_id;


-- "Edge" case
-- Question's keys are all over the place,
-- so we can avoid using the dot notation as long as we
-- can count on havin just one level of depth

WITH cte AS
    (
        SELECT
            id,
            batch_id,
            last_modified_date::timestamptz,
            questions as json_str
        FROM etl_reporting.stg_qlx_demo_survey
    ),

questions_expanded AS (
SELECT
    x.id,
    x.batch_id,
    x.last_modified_date,
    json_key as question_id,
    json_val.description AS question_body,
    json_val.choices AS answer_json_str
FROM cte AS x, x.json_str AS unnested, unpivot unnested AS json_val AT json_key
WHERE question_id = 'QID10'
)

SELECT
    q_e.id,
    q_e.batch_id,
    q_e.last_modified_date,
    q_e.question_id,
    q_e.question_body,
    json_key AS answer_id,
    json_val AS answer_body
FROM questions_expanded AS q_e, q_e.answer_json_str AS unnested, unpivot unnested AS json_val AT json_key;
