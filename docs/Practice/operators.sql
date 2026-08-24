--AND operator -- Compares both conditions have to be true
--retrieve customers from USA and have a score > than 500
select * from Sales.Customers
where Country = 'USA' and Score > 500

--OR Operator
--Atleast one confition should be true
--retrieve all customers who are either from USA or have a score > 500
select * from Sales.Customers
where Country = 'USA' or Score > 500

--NOT Operator
--Reverse operator - excludes the matching values
--Customers that dont fullfill the condition
--Task: retrieve all customers with score not less than 500
select * from Sales.Customers
where not Score < 500

--BETWEEN OPERATOR
--Checks for conditions in a range.
--all between the range is TRUE and outside the range is FALSE
--TASK: retrieve all customers whose score falls in the range between 100 and 500
select * from Sales.Customers
where Score between 100 and 500

--IN OPERATOR
--checks all members in a list and fullfill that condition
--Define the members of the list and use the operator to check the condition.
--TASK: retrieve all customers from either germany or USA
select * from Sales.Customers
where Country in ('Germany','USA')

--Search operator
--LIKE OPERATOR
--used to search for a pattern in a text
--add a where clause
--Task:Find all customers whose first name starts with 'M'
select *
from Sales.Customers
where FirstName like 'M%'

--Find all customers whose firstame ends with 'n'
select *
from Sales.Customers
where FirstName like '%n'

-- find all customers whose firstname contains 'r'
select *
from Sales.Customers
where FirstName like '%r%'

--find all customers whose firstname has 'r' in the third position
select *
from Sales.Customers
where FirstName like '__r%'

