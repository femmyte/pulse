import React from 'react';
import Logo from './Logo';
import Button from './Button';
import Link from 'next/link';

const Nav = () => {
	return (
		<nav className='flex justify-between items-center px-[5rem] mt-[2.06rem]'>
			<div className='flex items-center'>
				<Logo />
				<ul className='flex ml-[4.06rem] gap-x-8'>
					<li>
						<Link
							href={'#'}
							className='text-slate-700 font-[600] text-[1.125rem] leading-normal hover:text-slate-800'
						>
							Solution
						</Link>
					</li>
					<li>
						<Link
							href={'#'}
							className='text-slate-700 font-[600] text-[1.125rem] leading-normal hover:text-slate-800'
						>
							Market Place
						</Link>
					</li>
					<li>
						<Link
							href={'#'}
							className='text-slate-700 font-[600] text-[1.125rem] leading-normal hover:text-slate-800'
						>
							Learn
						</Link>
					</li>
					<li>
						<Link
							href={'#'}
							className='text-slate-700 font-[600] text-[1.125rem] leading-normal hover:text-slate-800'
						>
							About
						</Link>
					</li>
					<li>
						<Link
							href={'#'}
							className='text-slate-700 font-[600] text-[1.125rem] leading-normal hover:text-slate-800'
						>
							Customer Stories
						</Link>
					</li>
				</ul>
			</div>
			<div className='flex gap-x-[1.25rem] items-center'>
				<Link
					href={'/signin'}
					className='text-slate-800 hover:text-slate-600 text-[1.125rem] leading-normal font-[600]'
				>
					Login
				</Link>
				<Button text={'Start Free Trial'} link={'/signup'} />
			</div>
		</nav>
	);
};

export default Nav;