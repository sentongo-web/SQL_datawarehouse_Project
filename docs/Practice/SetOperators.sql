--SET OPERATORS
--UNIONS
select 
	c.CustomerID,
	c.FirstName
from Sales.Customers c

union

select 
	e.EmployeeID,
	e.LastName
from Sales.Employees e

select 
	c.CustomerID,
	c.FirstName
from Sales.Customers c

union all

select 
	e.EmployeeID,
	e.LastName
from Sales.Employees e

---EXCEPT 
--Find employees who are not customers at the same time
-- Order of querirs matters to make sense and get accurate results
select 
	FirstName,
	LastName
from Sales.Employees 
except
select 
	FirstName,
	LastName
from Sales.Customers 

--INTERSECT
--Find customers who are also customers
select 
	FirstName,
	LastName
from Sales.Employees 
intersect
select 
	FirstName,
	LastName
from Sales.Customers
