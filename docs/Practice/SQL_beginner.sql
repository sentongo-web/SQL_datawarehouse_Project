--Final SQL practicing
use SalesDB
-- exploring the sales database
select * from Sales.Orders;
--selecting only a few columns
select
	ProductID,
	CustomerID,
	Sales
from Sales.Orders
---filtering the data using the where clause basing on a condition
select
	ProductID,
	CustomerID,
	Sales
from Sales.Orders
where Sales >= 50

--Retrieve customers with a score not equal to 0
select 
	FirstName,
	LastName,
	Score
from Sales.Customers
where Score != 0

--Retrieve customers from Germany
select 
	FirstName,
	LastName,
	Country
from Sales.Customers
where Country = 'Germany'

--Sorting data using the ORDERBY
--Choose between sorting DESC OR ASC
-- Retrieve all customers and sort the resuls by the highest score first
select 
	FirstName,
	LastName,
	Score
from Sales.Customers
order by score desc  

--refine the sorting
-- Retrieve all customers and sort the resuls by the highest score first and country in ascending way
select 
	FirstName,
	LastName,
	Country,
	Score
from Sales.Customers
order by Country asc, Score desc  

--How to aggregate and group up data using group by
--find the total score for each country
-- To add another column, it must be placed within the group by or in an aggregation
select 
	Country,
	sum(Score)Total_Scores
from Sales.Customers
group by Country

-- find the total score and total number of customers for each country
select 
	Country,
	sum(Score)Total_Scores,
	count(CustomerID)Total_Customers
from Sales.Customers
group by Country

/*select * from Sales.Customers*/
--The Having clause.
--Used after a group by
--Use the aggregated column to further filter usin Having clause.
--Having is used to filter data after an aggregation

-- find the average score for each country considering only customers with a score not equal to 0 and return only coubntries with an average score greater than 500
select * from Sales.Customers

select 
	Country,
	avg(Score)Average_Score
from Sales.Customers
where Score <> 0
group by Country
having avg(Score) > 500

---Distinct Keyword: Used to remove duplicates such that each value only appears once
-- Only use distinct whyere it makese sense. Using distinct on Id values doesnt make sense and instead slows down the query
-- Return a unique list of all countries
select distinct 
	Country 
from Sales.Customers

-- Limiting data using the Top. limits the number of rows you want to see iun the results
-- Top
-- Retrieve only 2 customers with the highest scores
select top 2 * from Sales.Customers
order by Score desc


-- Find the 2 most recent Orders
select top 2 * from Sales.Orders
order by OrderDate desc


-- DDL - DATA DEFINITION LANGUAGE
--CREATE keyword
--Task: Create a new table called persons with columns: id, person_name,birth_date and phone

create table persons (
	id int not null,
	person_name varchar (50) not null,
	birth_date date,
	phone varchar (15) not null,
	constraint pk_persons primary key (id)
)

--Edit or change the definition of the table.
--Add a new column email to the persons table
alter table persons
add email varchar (20) not null

--check the table
select * from persons
--DROP COLUMNS
--remove the column phone from the persons table
alter table persons
drop column phone


drop table persons
-- DML -- DATA MANIPULATION LANGUAGE -- INSERTING VALUES

--insert values into the persons table
select * from Sales.Customers
insert into Sales.Customers(CustomerID,FirstName,LastName,Country,Score)
	values (6,'Sam',null,'USA',250),
	       (7,'Moses','Fritz','USA',470)
--bulk insert data into another table.
--TASK: Copy data from customers into persons

---insert into -----
---select * from ----
--UPDATE
--Specify a where clause to only impact the specified rows
--TASK: Change the score of customer 6 to 0
update Sales.Customers
set Score = 0
where CustomerID = 6

--change the score of customer 7 to 0 and update the country to UK
update Sales.Customers
set Score = 0,
	Country = 'UK'
where CustomerID = 7
-- Update all customers with a NULL score by setting thei score to 0

update Sales.Customers
set Score = 0
where Score is null

--DELETE Keyword
--Removes Rows from the table
--Delete from table_name
--add the where clause to filter only the rows
--Task-- Delete all customers with id greater than 5
delete from Sales.Customers
where CustomerID > 5

--TRUNCATE Keyword
--Faster than delete
--Delete all data from table persons
truncate table persons;

